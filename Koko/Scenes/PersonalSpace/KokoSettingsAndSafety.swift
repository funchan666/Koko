import SwiftUI
import UserNotifications

struct KokoSettingsView: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @State private var confirmation: String?
    var body: some View {
        ZStack {
            KokoPage(title: "Comfort comes first", subtitle: "Make Koko feel right for you", back: navigation.back) {
                KokoMenuRow(title: "Your profile", icon: 3) { navigation.open(.editProfile) }
                KokoMenuRow(title: "Privacy & invitations", icon: 11) { navigation.open(.preferences("Privacy")) }
                KokoMenuRow(title: "Notifications", icon: 10) { navigation.open(.preferences("Notifications")) }
                KokoMenuRow(title: "Account & sign-in", icon: 3) { navigation.open(.preferences("Account")) }
                KokoMenuRow(title: "Storage", icon: 9) { navigation.open(.preferences("Storage")) }
                KokoMenuRow(title: "Blocked people", icon: 3) { navigation.open(.blacklist) }
                KokoMenuRow(title: "Community guidelines", icon: 2) { navigation.open(.policy("Community guidelines")) }
                KokoMenuRow(title: "Privacy notice", icon: 11) { navigation.open(.policy("Privacy")) }
                KokoMenuRow(title: "Terms of Service", icon: 11) { navigation.open(.policy("Terms of Service")) }
                KokoMenuRow(title: "About Koko", detail: "Version 1.0 · Preview", icon: 1) { navigation.open(.preferences("About Koko")) }
                KokoAction(title: "Switch account", emphasis: false) { confirmation = "Switch accounts?" }
                KokoAction(title: "Sign out", emphasis: false) { confirmation = "Sign out?" }
                KokoAction(title: "Delete profile", emphasis: false) { confirmation = "Delete your profile?" }
            }
            if let confirmation {
                KokoModal(title: confirmation, dismiss: { self.confirmation = nil }) {
                    let deleting = confirmation == "Delete your profile?"
                    Text(deleting ? "This permanently removes this account's profile, messages, album, rooms, remaining coins, purchase records and keepsakes. Completed consumable purchases cannot restore this deleted balance. Other accounts are kept." : "Your data stays here. Use the same email with any password of 8–128 characters, or the same Apple account, to return.")
                    KokoAction(title: deleting ? "Delete this profile" : "Continue") {
                        if deleting { community.deleteLocalAccount() } else { community.signOut() }
                    }
                    KokoAction(title: "Keep me here", emphasis: false) { self.confirmation = nil }
                }
            }
        }
    }
}

struct KokoPreferencesView: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    let kind: String
    @State private var clearingMessages = false
    private var options: [String] { kind == "Privacy" ? ["Show my activity", "Allow room invitations"] : ["Message reminders", "Check-in reminders", "Room updates"] }
    var body: some View {
        ZStack {
            KokoPage(title: kind, back: navigation.back) {
                if kind == "Privacy" || kind == "Notifications" {
                    Artwork(sheet: .navigation, tile: kind == "Privacy" ? 11 : 10).frame(height: 120)
                    ForEach(options, id: \.self) { option in
                        KokoToggleRow(title: option, enabled: Binding(get: { community.journal?.preferences[option] ?? false }, set: { value in
                            if option == "Check-in reminders" {
                                let accountID = community.myID
                                Task {
                                    if value {
                                        do {
                                            try await KokoLocalReminders.enable()
                                            guard community.myID == accountID else { KokoLocalReminders.disable(); return }
                                            if !community.update({ $0.preferences[option] = true }) { KokoLocalReminders.disable() }
                                        } catch { community.notice = "Check-in reminders need notification permission. You can enable it in iOS Settings." }
                                    } else { KokoLocalReminders.disable(); community.update { $0.preferences[option] = false } }
                                }
                            } else { community.update { $0.preferences[option] = value } }
                        }))
                    }
                    Text(kind == "Privacy" ? "These choices are stored on this device. Remote profile visibility will be connected with the live service." : "Check-in reminders arrive at 8 p.m. Message and room preferences are saved for the future live service.")
                        .font(.custom("AvenirNext-Regular", size: 13)).foregroundStyle(KokoInk.secondary)
                } else if kind == "Storage" {
                    Artwork(sheet: .navigation, tile: 9).frame(height: 140)
                    KokoCard { VStack(alignment: .leading, spacing: 10) { Text("Saved on this device").font(.custom("AvenirNext-Bold", size: 22)); Text("\(community.conversations.count) conversations"); Text("\((community.journal?.albumTiles.count ?? 0) + (community.journal?.albumPhotoKeys?.count ?? 0)) album images"); Text("\(community.journal?.createdRooms.count ?? 0) rooms created") } }
                    KokoAction(title: "Clear media cache", emphasis: false) { community.clearTransientCache() }
                    KokoAction(title: "Clear conversations", emphasis: false) { clearingMessages = true }
                } else if kind == "Account" {
                    Text(community.currentMember?.publicName ?? "Your profile").font(.custom("AvenirNext-Bold", size: 27))
                    Text("Email entry checks a valid email format and an 8–128 character password only. The email selects your profile. It does not check a saved password or verify mailbox ownership.")
                    Text("Apple sign-in, when configured, uses genuine Apple authorization. Koko interactions stay on this device in this build.")
                    KokoAction(title: "Password help", emphasis: false) { community.notice = "Use the same email and any password of 8–128 characters. No password matching or reset is needed for this preview." }
                } else {
                    Artwork(sheet: .navigation, tile: 1)
                        .frame(width: 30, height: 30)
                        .padding(20)
                        .background(KokoControlSurface())
                    Text("koko").font(.custom("AvenirNext-Bold", size: 40))
                    Text("Good company, at your pace.").font(.custom("AvenirNext-DemiBold", size: 21))
                    Text("Version 1.0 · Original artwork · Native SwiftUI")
                    Text("This is an interactive preview with sample profiles and rooms. Optional coin packs use genuine Apple In-App Purchase, with the wallet currently stored on this device.").foregroundStyle(KokoInk.secondary)
                    KokoAction(title: "Leave feedback", icon: 2) { navigation.open(.feedback) }
                }
            }
            if clearingMessages { KokoModal(title: "Clear conversations?", dismiss: { clearingMessages = false }) { Text("This removes all saved chat entries and drafts for this account."); KokoAction(title: "Clear now") { community.update { $0.privateConversations = [] }; clearingMessages = false } } }
        }
    }
}

enum KokoLocalReminders {
    static let identifier = "koko.daily-visit"
    static func enable() async throws {
        let center = UNUserNotificationCenter.current()
        guard try await center.requestAuthorization(options: [.alert, .sound]) else { throw ReminderFailure.permissionDenied }
        let content = UNMutableNotificationContent()
        content.title = "A little time for yourself"
        content.body = "Your Koko check-in is here whenever you're ready."
        content.sound = .default
        var date = DateComponents(); date.hour = 20; date.minute = 0
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: date, repeats: true))
        try await center.add(request)
    }
    static func disable() { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier]) }
    enum ReminderFailure: Error { case permissionDenied }
}

struct KokoFeedbackView: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @State private var topic = "Something to improve"
    @State private var message = ""
    var body: some View {
        KokoPage(title: "Leave us a little note", back: navigation.back) {
            Artwork(sheet: .navigation, tile: 2)
                .frame(width: 30, height: 30)
                .padding(20)
                .background(KokoControlSurface())
            KokoChoiceRail(choices: ["Something to improve", "A problem", "An idea"], selection: $topic)
            KokoField(label: "What's on your mind? · up to 1000 characters", value: $message, multiline: true)
            KokoAction(title: "Save feedback", icon: 12) {
                let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, trimmed.count <= 1000 else { community.notice = "Write a note from 1 to 1000 characters."; return }
                if community.update({ $0.feedbackNotes.append(topic + ": " + trimmed) }) { message = ""; community.notice = "Your feedback is saved on this device. It has not been sent to a support team." }
            }
            Text("Your saved notes").font(.custom("AvenirNext-Bold", size: 20))
            ForEach(Array((community.journal?.feedbackNotes ?? []).enumerated()), id: \.offset) { _, note in KokoCard { Text(note).font(.custom("AvenirNext-Regular", size: 14)) } }
        }
    }
}

struct KokoBlacklistView: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @State private var selectedID: String?
    var body: some View {
        ZStack {
            KokoPage(title: "Your boundaries matter", subtitle: "People hidden on this device", back: navigation.back) {
                let blocked = KokoCommunity.members.filter { community.journal?.blockedMembers.contains($0.id) == true }
                if blocked.isEmpty { KokoEmpty(title: "Nothing here, and that's okay", detail: "People you block will appear here. You can unblock them at any time.") }
                ForEach(blocked) { member in KokoCard { HStack { KokoMemberPortrait(member: member).frame(width: 60, height: 60); Text(member.publicName).font(.custom("AvenirNext-DemiBold", size: 16)); Spacer(); Button("Unblock") { selectedID = member.id }.buttonStyle(.plain).font(.custom("AvenirNext-Medium", size: 12)) } } }
            }
            if let memberID = selectedID { KokoModal(title: "Unblock this person?", dismiss: { selectedID = nil }) { Text("Their content can appear again. Your previous follow relationship will not be restored automatically."); KokoAction(title: "Unblock") { community.update { $0.blockedMembers.remove(memberID); $0.hiddenContentKeys.remove(memberID) }; selectedID = nil } } }
        }
    }
}
