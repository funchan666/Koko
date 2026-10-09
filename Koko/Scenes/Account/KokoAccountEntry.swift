import SwiftUI
import AuthenticationServices
import CryptoKit
import UIKit

struct KokoAccountEntry: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var journey: KokoAccessJourney
    @StateObject private var appleEntry = KokoAppleEntry()
    @State private var destination = "Welcome"
    @State private var emailAddress = ""
    @State private var passwordDraft = ""
    @State private var repeatedPassword = ""
    @State private var agreed = false
    @State private var showConsentPrompt = false
    @State private var document: KokoLegalDocument?
    private var welcome: Bool { destination == "Welcome" }
    private var registration: Bool { destination == "Sign up" }
    var body: some View {
        ZStack {
            Group {
                if welcome {
                    KokoSocialWelcome(agreed: $agreed, authorizing: appleEntry.authorizing,
                        logIn: { guard requireConsent() else { return }; destination = "Log in" },
                        appleSignIn: beginAppleSignIn,
                        signUp: { guard requireConsent() else { return }; destination = "Sign up" },
                        openPolicy: { document = $0 })
                } else { credentialPage }
            }.disabled(appleEntry.authorizing || journey.transitioning)
                .accessibilityHidden(showConsentPrompt || document != nil)
            if showConsentPrompt { KokoConsentRequiredPanel(dismiss: { showConsentPrompt = false }) { document = $0 } }
            if let document { KokoLegalWebPage(document: document) { self.document = nil }.id(document) }
        }.onAppear(perform: updateWelcomeAppearance)
            .onChange(of: destination) { _ in updateWelcomeAppearance() }
            .onChange(of: document) { _ in updateWelcomeAppearance() }
            .onChange(of: showConsentPrompt) { _ in updateWelcomeAppearance() }
            .onDisappear { journey.usesDarkWelcomeAppearance = false }
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
                               destination = registration ? "Log in" : "Sign up"
                               passwordDraft = ""; repeatedPassword = ""
                           }, submit: submit, openPolicy: { document = $0 })
            .id(destination)
    }
    private func beginAppleSignIn() {
        guard requireConsent() else { return }
        appleEntry.start { identity, name in
            journey.enter(caption: "Getting ready…") {
                _ = community.enterAppleIdentity(identity, fullName: name, consent: agreed)
            }
        } failure: { community.notice = $0 }
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
        journey.enter(caption: isRegistration ? "Creating your account…" : "Getting ready…") {
            let success: Bool
            if isRegistration { success = await community.register(email: email, password: password, consent: agreed) }
            else { success = await community.signIn(email: email, password: password, consent: agreed) }
            if success { passwordDraft = ""; repeatedPassword = "" }
        }
    }
}

@MainActor
final class KokoAppleEntry: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    @Published private(set) var authorizing = false
    private var success: ((String, String?) -> Void)?
    private var failure: ((String) -> Void)?
    private var authorization: ASAuthorizationController?
    private var requestState: String?
    func start(success: @escaping (String, String?) -> Void, failure: @escaping (String) -> Void) {
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
        success?(credential.user, fullName ?? UserDefaults.standard.string(forKey: cacheKey))
    }
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        defer { clearRequest() }
        if (error as? ASAuthorizationError)?.code != .canceled {
            failure?("Apple sign-in could not complete. This installation needs a matching App ID, developer team and Sign in with Apple capability. Please try again when configured.")
        }
    }
    private func clearRequest() { authorization = nil; success = nil; failure = nil; requestState = nil; authorizing = false }
}

struct KokoPolicyView: View {
    let kind: String
    var onBack: () -> Void
    var body: some View {
        if kind == "Community guidelines" {
            KokoPage(title: kind, back: onBack) {
                Artwork(sheet: .arrival, tile: 1).frame(height: 210)
                Text("Make room for one another.").font(.custom("AvenirNext-Bold", size: 26))
                Text("Respect people's boundaries. Do not share harassment, hate, exploitation, threats, scams or private information. Report or block content that makes you uncomfortable.")
                Text("Koko is for adults. Reports remain on this device until a moderation service is connected.").foregroundStyle(KokoInk.secondary)
            }
        } else { KokoLegalWebPage(document: kind == "Privacy" ? .privacy : .terms, close: onBack) }
    }
}
