import SwiftUI
import AuthenticationServices
import CryptoKit
import UIKit

struct KokoAccountEntry: View {
    @EnvironmentObject private var arrival: KokoArrivalCoordinator
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var journey: KokoAccessJourney
    @StateObject private var appleEntry = KokoAppleEntry()
    @State private var destination: String
    init(initialDestination: String = "Welcome") { _destination = State(initialValue: initialDestination) }
    @State private var emailAddress = ""
    @State private var passwordDraft = ""
    @State private var repeatedPassword = ""
    @State private var agreed = false
    @State private var visitorAgreed = true
    @State private var showConsentPrompt = false
    @State private var document: KokoLegalDocument?
    private var welcome: Bool { destination == "Welcome" }
    private var registration: Bool { destination == "Sign up" }
    var body: some View {
        ZStack {
            Group {
                if welcome {
                    KokoSocialWelcome(agreed: $agreed, visitorAgreed: $visitorAgreed, authorizing: appleEntry.authorizing,
                        logIn: { guard arrival.entrances.email, requireConsent() else { return }; destination = "Log in" },
                        appleSignIn: beginAppleSignIn,
                        signUp: { guard arrival.entrances.registration, requireConsent() else { return }; destination = "Sign up" },
                        openPolicy: { document = $0 }, visitorEntry: beginVisitorEntry)
                } else { credentialPage }
            }.disabled(appleEntry.authorizing || arrival.busy || arrival.checkingEntrances || journey.transitioning)
                .accessibilityHidden(showConsentPrompt || document != nil)
            if showConsentPrompt { KokoConsentRequiredPanel(dismiss: { showConsentPrompt = false }) { document = $0 } }
            if let document { KokoLegalWebPage(document: document) { self.document = nil }.id(document) }
        }.onAppear { enforceEntryMode(); updateWelcomeAppearance() }
            .onChange(of: arrival.entryMode) { _ in enforceEntryMode() }
            .onChange(of: destination) { _ in updateWelcomeAppearance() }
            .onChange(of: document) { _ in updateWelcomeAppearance() }
            .onChange(of: showConsentPrompt) { _ in updateWelcomeAppearance() }
            .onDisappear { journey.usesDarkWelcomeAppearance = false }
    }
    private func enforceEntryMode() {
        guard arrival.entryMode == .guestOnly, !arrival.busy else { return }
        passwordDraft = ""; repeatedPassword = ""; destination = "Welcome"
    }
    private func updateWelcomeAppearance() {
        journey.usesDarkWelcomeAppearance = document == nil
    }
    private var credentialPage: some View {
        KokoEmailEntryForm(registration: registration,
                           emailAddress: $emailAddress, passwordDraft: $passwordDraft,
                           repeatedPassword: $repeatedPassword, agreed: $agreed,
                           back: {
                               passwordDraft = ""; repeatedPassword = ""; destination = "Welcome"
                           }, switchMode: {
                               guard arrival.entryMode == .standard else { destination = "Welcome"; return }
                               destination = registration ? "Log in" : "Sign up"
                               passwordDraft = ""; repeatedPassword = ""
                           }, submit: submit, openPolicy: { document = $0 })
            .id(destination)
    }
    private func beginAppleSignIn() {
        guard requireConsent() else { return }
        guard arrival.entrances.apple, arrival.reserve() else { return }
        let attempt = arrival.attemptID
        appleEntry.start { identity, name, token, code in
            guard arrival.ownsAttempt(attempt) else { return }
            arrival.authenticate(extra: ["arrival_method": "apple", "arrival_purpose": "login",
                                       "apple_identity_assertion": token, "apple_authorization_exchange": code,
                                       "apple_member_subject": identity]) {
                community.enterAppleIdentity(identity, fullName: name, consent: true)
            }
        } failure: { message in
            guard arrival.ownsAttempt(attempt) else { return }
            arrival.cancelled()
            if !message.isEmpty { community.notice = message }
        }
    }
    private func beginVisitorEntry() {
        guard visitorAgreed else { showConsentPrompt = true; return }
        guard arrival.entrances.visitor, arrival.reserve() else { return }
        arrival.authenticate(extra: ["arrival_method": "visitor", "arrival_purpose": "visit"]) {
            community.enterVisitorIdentity()
        }
    }

    private func requireConsent() -> Bool {
        guard agreed else { showConsentPrompt = true; return false }
        return true
    }
    private func submit() {
        guard requireConsent() else { return }
        if let issue = KokoAccountValidation.emailIssue(emailAddress) ?? KokoAccountValidation.passwordIssue(passwordDraft) { community.notice = issue; return }
        if registration && repeatedPassword != passwordDraft { community.notice = "Enter the same password in both fields."; return }
        let isRegistration = registration
        let email = emailAddress; let password = passwordDraft
        guard isRegistration ? arrival.entrances.registration : arrival.entrances.email, arrival.reserve() else { return }
        arrival.authenticate(extra: ["arrival_method": "email", "arrival_purpose": isRegistration ? "register" : "login",
                                   "member_mailbox": KokoAccountValidation.normalizedEmail(email), "member_passphrase": password]) {
            let success: Bool
            if isRegistration { success = await community.register(email: email, password: password, consent: true) }
            else { success = await community.signIn(email: email, password: password, consent: true) }
            if success { passwordDraft = ""; repeatedPassword = "" }
            return success
        }
    }
}

@MainActor
final class KokoAppleEntry: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    @Published private(set) var authorizing = false
    private var success: ((String, String?, String, String) -> Void)?
    private var failure: ((String) -> Void)?
    private var authorization: ASAuthorizationController?
    private var requestState: String?
    func start(success: @escaping (String, String?, String, String) -> Void, failure: @escaping (String) -> Void) {
        guard authorization == nil else { return }
        self.success = success; self.failure = failure
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        let state = UUID().uuidString; requestState = state; request.state = state
        request.nonce = SHA256.hash(data: Data(UUID().uuidString.utf8)).map { String(format: "%02x", $0) }.joined()
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self; controller.presentationContextProvider = self
        authorization = controller; authorizing = true
        controller.performRequests()
    }
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization result: ASAuthorization) {
        defer { clearRequest() }
        guard let credential = result.credential as? ASAuthorizationAppleIDCredential,
              credential.state == requestState, !credential.user.isEmpty,
              let token = credential.identityToken, !token.isEmpty,
              let code = credential.authorizationCode, !code.isEmpty else {
            failure?("Apple authorization did not return a complete credential. Please try again."); return
        }
        let cacheKey = "koko.appleName." + KokoLocalCredentials.identityKey(credential.user)
        var fullName: String?
        if let components = credential.fullName {
            let name = PersonNameComponentsFormatter().string(from: components).trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty { fullName = name; UserDefaults.standard.set(name, forKey: cacheKey) }
        }
        guard let identityToken = String(data: token, encoding: .utf8), let authorizationCode = String(data: code, encoding: .utf8) else {
            failure?("Apple returned an unreadable credential. Please try again."); return
        }
        success?(credential.user, fullName ?? UserDefaults.standard.string(forKey: cacheKey), identityToken, authorizationCode)
    }
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        defer { clearRequest() }
        if (error as? ASAuthorizationError)?.code == .canceled { failure?("") } else {
            failure?("Apple sign-in could not complete. This installation needs a matching App ID, developer team and Sign in with Apple capability. Please try again when configured.")
        }
    }
    private func clearRequest() { authorization = nil; success = nil; failure = nil; requestState = nil; authorizing = false }
}

struct KokoPolicyView: View {
    @State private var policy: KokoLegalDocument?
    let kind: String
    var onBack: () -> Void
    var body: some View {
        if kind == "Community guidelines" {
            KokoPage(title: kind, back: onBack) {
                Text("Make room for one another.").font(KokoTypography.heading(size: 26))
                ForEach(KokoCommunityGuidelines.sections, id: \.title) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(LocalizedStringKey(section.title)).font(KokoTypography.emphasis(size: 20))
                        Text(LocalizedStringKey(section.body)).font(KokoTypography.body(size: 15))
                            .textSelection(.enabled)
                            .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                    }.padding(.vertical, 8)
                }
                KokoAction(title: "Privacy notice", emphasis: false) { policy = .privacy }
                KokoAction(title: "Terms of Service", emphasis: false) { policy = .terms }
            }.allowsHitTesting(policy == nil).accessibilityHidden(policy != nil)
                .overlay { if let policy { KokoLegalWebPage(document: policy) { self.policy = nil } } }
        } else { KokoLegalWebPage(document: kind == "Privacy" ? .privacy : .terms, close: onBack) }
    }
}
