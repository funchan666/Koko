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
            KokoPage(title: "koko", subtitle: "GOOD COMPANY, AT YOUR PACE", back: welcome ? nil : { passwordDraft = ""; repeatedPassword = ""; destination = "Welcome" }) {
                Artwork(sheet: .arrival, tile: welcome ? 2 : 3).frame(height: welcome ? 235 : 145)
                Text(welcome ? "A little closer.\nA little more you." : (registration ? "Make room\nfor yourself." : "Good to have\nyou here."))
                    .font(.custom("AvenirNext-Bold", size: 35)).lineSpacing(-2)
                if welcome {
                    Text("Find a conversation, share a moment, make yourself at home.").foregroundStyle(KokoInk.secondary)
                    KokoAction(title: "Log in", icon: 12) { guard requireConsent() else { return }; destination = "Log in" }
                    KokoAction(title: appleEntry.authorizing ? "Waiting for Apple…" : "Continue with Apple", emphasis: false) {
                        guard requireConsent() else { return }
                        appleEntry.start { identity, name in
                            journey.enter(caption: "Your space is taking shape.") {
                                _ = community.enterAppleIdentity(identity, fullName: name, consent: agreed)
                            }
                        } failure: { community.notice = $0 }
                    }.disabled(appleEntry.authorizing)
                    Button("New here? Sign up") { guard requireConsent() else { return }; destination = "Sign up" }
                        .font(.custom("AvenirNext-DemiBold", size: 14)).buttonStyle(.plain).frame(maxWidth: .infinity, minHeight: 44)
                } else {
                    KokoField(label: "Email address", value: $emailAddress, keyboard: .emailAddress)
                    KokoField(label: "Password · 8–128 characters", value: $passwordDraft, secure: true)
                    if registration { KokoField(label: "Confirm password", value: $repeatedPassword, secure: true) }
                    KokoAction(title: registration ? "Sign up" : "Start", icon: 12, action: submit)
                    KokoAction(title: registration ? "Already have an account? Log in" : "No account yet? Sign up", emphasis: false) {
                        destination = registration ? "Log in" : "Sign up"; passwordDraft = ""; repeatedPassword = ""
                    }
                    if !registration {
                        Button("Password help") { community.notice = "Use the password you registered on this device. Koko does not email password resets yet. Earlier preview profiles can set their first password through Sign up using the same email." }
                            .font(.custom("AvenirNext-Medium", size: 12)).buttonStyle(.plain).frame(minHeight: 44)
                    }
                    Text("Your account stays signed in on this device until you choose to sign out.")
                        .font(.custom("AvenirNext-Regular", size: 12)).foregroundStyle(KokoInk.secondary)
                }
                KokoConsentFooter(agreed: $agreed) { document = $0 }
            }.disabled(appleEntry.authorizing || journey.transitioning)
            if showConsentPrompt { KokoConsentRequiredPanel(dismiss: { showConsentPrompt = false }) { document = $0 } }
            if let document { KokoLegalWebPage(document: document) { self.document = nil }.id(document) }
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
        journey.enter(caption: isRegistration ? "Making room for you." : "Your company is waiting.") {
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
                Text("Koko is for adults. Local reports remain on this device until a moderation service is connected.").foregroundStyle(KokoInk.secondary)
            }
        } else { KokoLegalWebPage(document: kind == "Privacy" ? .privacy : .terms, close: onBack) }
    }
}
