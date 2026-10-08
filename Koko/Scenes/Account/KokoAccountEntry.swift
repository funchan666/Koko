import SwiftUI
import AuthenticationServices
import UIKit

struct KokoAccountEntry: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @StateObject private var appleEntry = KokoAppleEntry()
    @State private var emailAddress = ""
    @State private var passwordDraft = ""
    @State private var formVisible = false
    @State private var creatingProfile = false
    @State private var hasReadPreviewNotice = false
    @State private var policy: String?
    var body: some View {
        ZStack {
            KokoPage(title: "koko", subtitle: "GOOD COMPANY, AT YOUR PACE") {
                Artwork(sheet: .scenes, tile: 3).frame(maxHeight: formVisible ? 175 : 310)
                Text(formVisible ? (creatingProfile ? "Make room\nfor yourself." : "Good to have\nyou here.") : "A little closer.\nA little more you.")
                    .font(.custom("AvenirNext-Bold", size: 35, relativeTo: .largeTitle)).lineSpacing(-2)
                Text("Drop into a conversation. Share what moves you. Find your kind of company.")
                    .foregroundStyle(KokoInk.secondary)
                if formVisible {
                    KokoField(label: "Email address", value: $emailAddress, keyboard: .emailAddress)
                    KokoField(label: "Password · 8–128 characters", value: $passwordDraft, secure: true)
                    KokoToggleRow(title: "I understand this is a local preview", enabled: $hasReadPreviewNotice)
                    LocalPreviewNote(text: "ANY VALID EMAIL WORKS HERE. PASSWORDS ARE NOT STORED OR SENT.")
                    KokoAction(title: creatingProfile ? "Create my local profile" : "Enter Koko", icon: 12) {
                        guard hasReadPreviewNotice else { community.notice = "Please acknowledge the local preview notice first."; return }
                        if community.signIn(email: emailAddress, password: passwordDraft) { passwordDraft = "" }
                    }
                    KokoAction(title: creatingProfile ? "Already have a local profile? Sign in" : "New here? Create a profile", emphasis: false) { creatingProfile.toggle() }
                    KokoAction(title: "Forgot password?", emphasis: false) { community.notice = "This preview checks password length only. Enter any 8–128 character password with the same email to reopen your local profile." }
                } else {
                    KokoAction(title: "Come on in", icon: 12) { formVisible = true }
                }
                KokoAction(title: "Continue with Apple", emphasis: false) {
                    appleEntry.start { identity, name in _ = community.enterAppleIdentity(identity, givenName: name) } failure: { community.notice = $0 }
                }
                HStack {
                    Button("Preview terms") { policy = "Preview terms" }
                    Spacer()
                    Button("Privacy") { policy = "Privacy" }
                }.font(.custom("AvenirNext-Medium", size: 12)).buttonStyle(.plain).padding(.vertical, 6)
                LocalPreviewNote()
            }
            if let policy { KokoPolicyView(kind: policy, onBack: { self.policy = nil }) }
        }
    }
}

@MainActor
final class KokoAppleEntry: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var success: ((String, String?) -> Void)?
    private var failure: ((String) -> Void)?
    private var authorization: ASAuthorizationController?
    func start(success: @escaping (String, String?) -> Void, failure: @escaping (String) -> Void) {
        guard authorization == nil else { return }
        self.success = success; self.failure = failure
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self; controller.presentationContextProvider = self
        authorization = controller
        controller.performRequests()
    }
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization result: ASAuthorization) {
        defer { authorization = nil; success = nil; failure = nil }
        guard let credential = result.credential as? ASAuthorizationAppleIDCredential else { failure?("Apple couldn't complete authorization."); return }
        success?(credential.user, credential.fullName?.givenName)
    }
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        defer { authorization = nil; success = nil; failure = nil }
        if (error as? ASAuthorizationError)?.code != .canceled {
            failure?("Apple sign-in isn't available for this installation. It needs your developer team's configured App ID. Email local preview remains available.")
        }
    }
}

struct KokoProfileEditor: View {
    @EnvironmentObject private var community: CommunityJournalStore
    let isOnboarding: Bool
    var onFinish: (() -> Void)? = nil
    @State private var displayName = ""
    @State private var hometown = ""
    @State private var introduction = ""
    @State private var age = "25"
    @State private var language = "English"
    @State private var gender = "Prefer not to say"
    @State private var portrait = 0
    @State private var interests: Set<String> = []
    var body: some View {
        KokoPage(title: isOnboarding ? "Your kind of space" : "Edit your profile", subtitle: "A few things that make you, you.", back: isOnboarding ? nil : onFinish) {
            HStack {
                Artwork(sheet: .collection, tile: portrait).frame(width: 110, height: 110)
                VStack(alignment: .leading, spacing: 8) { Text("Pick a starting portrait").font(.custom("AvenirNext-DemiBold", size: 16)); Text("Original placeholders. You can replace them later.").font(.custom("AvenirNext-Regular", size: 12)).foregroundStyle(KokoInk.secondary) }
            }
            HStack {
                ForEach(0..<4) { tile in
                    Button { portrait = tile } label: { Artwork(sheet: .collection, tile: tile).frame(height: 64).padding(6).background(ArtworkSurface(tile: portrait == tile ? 3 : 2)) }.buttonStyle(.plain).accessibilityLabel("Portrait \(tile + 1)")
                }
            }
            KokoField(label: "Display name", value: $displayName)
            KokoField(label: "City or region", value: $hometown)
            KokoField(label: "Age · 18 or older", value: $age, keyboard: .numberPad)
            KokoField(label: "A little about you", value: $introduction, multiline: true)
            Text("You describe yourself as").font(.custom("AvenirNext-DemiBold", size: 13))
            KokoChoiceRail(choices: ["Woman", "Man", "Non-binary", "Prefer not to say"], selection: $gender)
            Text("Conversation language").font(.custom("AvenirNext-DemiBold", size: 13))
            KokoChoiceRail(choices: ["English", "Portuguese", "French", "Spanish", "Mandarin"], selection: $language)
            Text("What brings you here?").font(.custom("AvenirNext-DemiBold", size: 18))
            ForEach(Array(KokoCommunity.topics.dropFirst()), id: \.self) { topic in
                KokoToggleRow(title: topic, enabled: Binding(get: { interests.contains(topic) }, set: { enabled in if enabled { interests.insert(topic) } else { interests.remove(topic) } }))
            }
            KokoAction(title: isOnboarding ? "Find my company" : "Save profile", icon: 12) {
                guard var member = community.currentMember else { return }
                member.publicName = String(displayName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
                member.hometownLabel = String(hometown.prefix(60)); member.introductionLine = String(introduction.prefix(240))
                member.adultAge = Int(age) ?? 0; member.genderLabel = gender; member.spokenLanguage = language
                member.portraitTile = portrait; member.interests = interests.sorted()
                if community.saveProfile(member) { onFinish?() }
            }
            if isOnboarding { KokoAction(title: "Back to sign in", emphasis: false) { community.signOut() } }
        }.onAppear {
            guard let member = community.currentMember else { return }
            displayName = member.publicName == "Your name" ? "" : member.publicName; hometown = member.hometownLabel
            introduction = member.introductionLine; age = String(member.adultAge); gender = member.genderLabel
            language = member.spokenLanguage; portrait = member.portraitTile; interests = Set(member.interests)
        }
    }
}

struct KokoPolicyView: View {
    let kind: String
    var onBack: () -> Void
    var body: some View {
        KokoPage(title: kind, back: onBack) {
            Artwork(sheet: .scenes, tile: 3).frame(height: 160)
            Text("A considered place to connect.").font(.custom("AvenirNext-Bold", size: 24))
            if kind == "Privacy" {
                Text("This build stores your profile, interactions, photos selected from the sample collection, and coin purchases and spending history on this device. Email is transformed into a local account key. Passwords are not saved or sent.")
                Text("Apple authorization uses Apple's genuine system flow if configured. Coin purchases use Apple In-App Purchase. Koko sends an account association token to Apple and saves verified transaction IDs locally; Apple handles payment details. There is no Koko server authentication, analytics or remote messaging in this version.")
                Text("Remove your local profile from Settings to delete its saved journal, including any remaining purchased coins. This device-local balance is not restored from completed consumable purchases. A local anonymous gift-eligibility flag prevents a second welcome gift after profile deletion. This preview notice will be replaced with the operator's published privacy policy before release.")
            } else {
                Text("Koko is currently a local product preview for adults. Sample people and rooms are illustrative. Messages and reports stay on your device. Optional coin packs are real Apple In-App Purchases. Coins are for in-app gifts and decorations, do not expire, and cannot be exchanged for cash. Conversations are free.")
                Text("Respect other people. Do not share harassment, hate, sexual exploitation, threats, scams or private information. Reporting and blocking are available throughout the experience.")
                Text("Production service terms, support contact and moderation procedures will be supplied before the service goes live. This page is a preview notice, not a published service agreement.")
            }
        }
    }
}
