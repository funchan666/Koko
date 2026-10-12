import Foundation
import CryptoKit
import Combine
import AuthenticationServices

@MainActor
final class CommunityJournalStore: ObservableObject {
    enum AccountDeparture {
        case signOut, deleteAccount

        var caption: String {
            switch self {
            case .signOut: return "Signing out…"
            case .deleteAccount: return "Deleting your account…"
            }
        }
    }

    @Published private(set) var journal: MemberAccountArchive?
    @Published private(set) var accountDeparture: AccountDeparture?
    @Published var notice: String?
    @Published var feedback: KokoActionFeedback?
    @Published var safetyRequest: KokoSafetyTarget?
    @Published private(set) var signedOutDestination = "Welcome"
    @Published private(set) var storageUnavailable = false
    @Published var coinSpendRequest: CoinSpendRequest?
    @Published var coinShortfall: CoinShortfall?
    @Published var purchaseInProgress = false
    @Published private(set) var requiresAppleProfileReview = false
    private var activeIdentity: String?
    private let fileManager = FileManager.default
    private let sessionPreference = "koko.activeLocalIdentity"

    init() {
        if let savedIdentity = UserDefaults.standard.string(forKey: sessionPreference) {
            do {
                let data = try Data(contentsOf: journalURL(savedIdentity))
                var restored = try JSONDecoder().decode(MemberAccountArchive.self, from: data)
                let portraitChanged = ensureSuppliedPortrait(&restored, identity: savedIdentity)
                let relationshipsChanged = removeSimulatedRelationships(&restored)
                if portraitChanged || relationshipsChanged {
                    try persist(restored, identity: savedIdentity)
                }
                journal = restored
                activeIdentity = savedIdentity
            } catch {
                storageUnavailable = true
                notice = "Your saved space couldn't be opened. It has not been replaced. Please try again."
            }
        }
    }

    var currentMember: CommunityMember? { journal?.member }
    var myID: String { journal?.member.id ?? "signed-out" }
    var following: Set<String> { journal?.followedMembers ?? [] }
    var followers: Set<String> { journal?.confirmedFollowerIDs ?? [] }
    var friends: Set<String> { following.intersection(followers).filter { isMemberVisible($0) } }
    var members: [CommunityMember] {
        KokoCommunity.members.filter { !(journal?.blockedMembers.contains($0.id) ?? false) && !(journal?.hiddenContentKeys.contains($0.id) ?? false) }
    }
    var rooms: [HostedConversationRoom] {
        (KokoCommunity.rooms + (journal?.createdRooms ?? [])).map { original in
            var room = journal?.roomOverrides[original.id] ?? original
            if let previousHost = KokoCommunity.previousVoiceRoomHosts[original.id],
               room.hostMemberID == previousHost {
                room.hostMemberID = original.hostMemberID
                room.seatAssignments = room.seatAssignments.filter { $0.value != original.hostMemberID }
                room.seatAssignments[0] = original.hostMemberID
                room.moderatorMemberIDs.remove(previousHost)
            }
            return room
        }
            .filter { isMemberVisible($0.hostMemberID) && !isContentHidden($0.id) }
            .map { room in
                var visible = room
                visible.seatAssignments = room.seatAssignments.filter { isMemberVisible($0.value) }
                visible.roomConversation = room.roomConversation.filter { isEntryVisible($0) }
                return visible
            }
    }
    var moments: [SharedMoment] {
        KokoCommunity.moments.filter {
            !KokoMediaLibrary.liveRoomPreviewAssetIDs.contains($0.libraryAssetKey ?? "")
                && !(journal?.hiddenContentKeys.contains($0.id) ?? false)
                && isMemberVisible($0.creatorMemberID)
        }
    }
    var conversations: [PrivateConversation] {
        (journal?.privateConversations ?? []).filter { isMemberVisible($0.correspondentID) && !isContentHidden("conversation-" + $0.correspondentID) }
            .map { conversation in var visible = conversation; visible.entries = conversation.entries.filter(isEntryVisible); return visible }
            .sorted { ($0.entries.last?.postedAt ?? .distantPast) > ($1.entries.last?.postedAt ?? .distantPast) }
    }
    var activityPoints: Int { (journal?.checkInDayKeys.count ?? 0) * 10 + (journal?.createdRooms.count ?? 0) * 20 }
    var activityLevel: Int { activityPoints / 200 + 1 }
    var todayKey: String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }
    var checkedInToday: Bool { journal?.checkInDayKeys.contains(todayKey) ?? false }

    func member(_ identifier: String) -> CommunityMember? {
        if identifier == myID { return currentMember }
        return KokoCommunity.members.first { $0.id == identifier }
    }
    func room(_ identifier: String) -> HostedConversationRoom? { rooms.first { $0.id == identifier } }
    var hasCurrentPolicyConsent: Bool { journal?.policyConsent?.revision == KokoPolicyConsent.currentRevision }
    var hasCompletedAccountEntry: Bool {
        guard let journal, !requiresAppleProfileReview else { return false }
        return journal.completedProfile || (journal.accountCredentialKind == "email" && journal.enteredHomeViaEmail == true)
    }

    func signIn(email: String, password: String, consent: Bool) async -> Bool {
        guard consent else { notice = "Please agree to the Terms of Service and Privacy Policy before continuing."; return false }
        if let issue = KokoAccountValidation.emailIssue(email) ?? KokoAccountValidation.passwordIssue(password) { notice = issue; return false }
        let key = KokoLocalCredentials.identityKey("email:" + KokoAccountValidation.normalizedEmail(email))
        do {
            // Local preview entry: validate format only; the email selects the saved space.
            var restored = try readSavedJournal(key) ?? newJournal(identity: key)
            restored.accountCredentialKind = "email"
            restored.policyConsent = KokoPolicyConsent()
            restored.enteredHomeViaEmail = true
            if restored.member.publicName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Use the supplied email handle; do not invent age, country, or interests.
                restored.member.publicName = String(KokoAccountValidation.normalizedEmail(email).split(separator: "@")[0].prefix(40))
            }
            try activate(restored, identity: key)
            requiresAppleProfileReview = false
            return true
        } catch { notice = "Your account could not be opened. Your saved data has been kept. Please try again."; return false }
    }

    func register(email: String, password: String, consent: Bool) async -> Bool {
        guard consent else { notice = "Please agree to both policies first."; return false }
        if let issue = KokoAccountValidation.emailIssue(email) ?? KokoAccountValidation.passwordIssue(password) { notice = issue; return false }
        let key = KokoLocalCredentials.identityKey("email:" + KokoAccountValidation.normalizedEmail(email))
        do {
            var draft = try readSavedJournal(key) ?? newJournal(identity: key)
            guard draft.accountCredentialKind == nil else { notice = "This account already exists on this device. Choose Log in with this email and any password of 8–128 characters."; return false }
            draft.accountCredentialKind = "email"; draft.policyConsent = KokoPolicyConsent(); draft.completedProfile = false
            try activate(draft, identity: key)
            return true
        } catch {
            notice = "Your profile could not be saved. Your existing data has been kept. Please try again."; return false
        }
    }

    /// Called only after genuine ASAuthorizationAppleIDCredential authorization completes.
    func enterAppleIdentity(_ identifier: String, fullName: String?, consent: Bool) -> Bool {
        guard consent, !identifier.isEmpty else { notice = "Agree to both policies and finish Apple authorization first."; return false }
        let key = KokoLocalCredentials.identityKey("apple:" + identifier)
        do {
            var restored = try readSavedJournal(key) ?? newJournal(identity: key)
            if restored.member.publicName.isEmpty, let fullName, !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Apple supplies names on first authorization. Save it immediately, even if profile editing is interrupted.
                restored.member.publicName = String(fullName.prefix(40))
            }
            restored.accountCredentialKind = "apple"; restored.appleSubjectIdentifier = identifier
            restored.policyConsent = KokoPolicyConsent()
            requiresAppleProfileReview = true
            try activate(restored, identity: key)
            return true
        } catch { requiresAppleProfileReview = false; notice = "Your Apple profile could not be saved on this device. Please try again."; return false }
    }

    func refreshAppleCredentialState() {
        guard let subject = journal?.appleSubjectIdentifier else { return }
        let owner = myID
        ASAuthorizationAppleIDProvider().getCredentialState(forUserID: subject) { [weak self] state, error in
            let mustSignIn = error == nil && (state == .revoked || state == .notFound || state == .transferred)
            Task { @MainActor in
                guard let self, self.myID == owner, mustSignIn else { return }
                self.invalidateAppleSession()
            }
        }
    }
    func invalidateAppleSession() {
        guard journal?.accountCredentialKind == "apple" else { return }
        // Revocation is authoritative even when a purchase is pending; its account token still protects delivery.
        journal = nil; activeIdentity = nil; requiresAppleProfileReview = false
        coinSpendRequest = nil; coinShortfall = nil
        UserDefaults.standard.removeObject(forKey: sessionPreference)
        notice = "Apple authorization has changed. Please sign in with Apple again. Your saved profile remains on this device."
    }
    func acceptCurrentPolicies() { update { $0.policyConsent = KokoPolicyConsent() } }
    private func readSavedJournal(_ identity: String) throws -> MemberAccountArchive? {
        let url = try journalURL(identity)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(MemberAccountArchive.self, from: Data(contentsOf: url))
    }
    private func newJournal(identity: String) -> MemberAccountArchive {
        var value = MemberAccountArchive(member: .init(id: identity, publicName: "", hometownLabel: "", spokenLanguage: "English", adultAge: 0, genderLabel: "", introductionLine: "", portraitTile: 0, interests: []))
        _ = ensureSuppliedPortrait(&value, identity: identity)
        value.welcomeGiftEligible = !UserDefaults.standard.bool(forKey: "koko.firstVisitGift." + identity)
        return value
    }
    private func activate(_ input: MemberAccountArchive, identity: String) throws {
        var value = input
        _ = ensureSuppliedPortrait(&value, identity: identity)
        _ = removeSimulatedRelationships(&value)
        try persist(value, identity: identity)
        activeIdentity = identity; journal = value; storageUnavailable = false
        UserDefaults.standard.set(identity, forKey: sessionPreference)
    }

    /// Gives a new device account one supplied photograph while keeping every
    /// sample host and previously saved account on a different portrait.
    @discardableResult
    private func ensureSuppliedPortrait(_ value: inout MemberAccountArchive, identity: String) -> Bool {
        guard value.member.portraitFileName == nil, value.member.suppliedPortraitPhotoKey == nil else { return false }
        let used = reservedPortraitKeys(excluding: identity)
        guard let key = KokoMediaLibrary.photos.first(where: { !used.contains($0.id) })?.id else { return false }
        value.member.suppliedPortraitPhotoKey = key
        return true
    }

    private func reservedPortraitKeys(excluding identity: String) -> Set<String> {
        var used = Set(KokoCommunity.members.compactMap(\.suppliedPortraitPhotoKey))
        guard let base = try? fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("KokoCommunity", isDirectory: true),
              let urls = try? fileManager.contentsOfDirectory(at: base, includingPropertiesForKeys: nil) else { return used }
        for url in urls where url.pathExtension == "json" && url.deletingPathExtension().lastPathComponent != identity {
            guard let data = try? Data(contentsOf: url),
                  let saved = try? JSONDecoder().decode(MemberAccountArchive.self, from: data),
                  let key = saved.member.suppliedPortraitPhotoKey else { continue }
            used.insert(key)
        }
        return used
    }
    @discardableResult
    func update(_ change: (inout MemberAccountArchive) -> Void) -> Bool {
        guard var next = journal, let identity = activeIdentity else { return false }
        change(&next)
        do {
            try persist(next, identity: identity)
            journal = next
            return true
        } catch { notice = "Couldn't save this change. Your previous data is safe. Please try again."; return false }
    }
    private func journalURL(_ identity: String) throws -> URL {
        let base = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("KokoCommunity", isDirectory: true)
        try fileManager.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent(identity + ".json")
    }
    private func persist(_ value: MemberAccountArchive, identity: String) throws {
        let data = try JSONEncoder().encode(value)
        try data.write(to: journalURL(identity), options: [.atomic, .completeFileProtectionUnlessOpen])
    }
    func signOut() {
        beginAccountDeparture(.signOut)
    }

    func deleteLocalAccount() {
        beginAccountDeparture(.deleteAccount)
    }

    private func beginAccountDeparture(_ departure: AccountDeparture) {
        guard accountDeparture == nil else { return }
        guard !purchaseInProgress else { notice = "Please finish or cancel the Apple purchase first."; return }
        let identity = activeIdentity
        if departure == .deleteAccount && identity == nil {
            notice = "Your account could not be deleted. Please try again."
            return
        }
        accountDeparture = departure
        feedback = nil
        notice = nil
        Task {
            defer { accountDeparture = nil }
            // Allow the root loading surface to render before disk/keychain work.
            // This is a visual transition, not a simulated server request.
            do { try await Task.sleep(nanoseconds: 150_000_000) } catch { return }
            guard activeIdentity == identity else { return }
            guard !purchaseInProgress else { notice = "Please finish or cancel the Apple purchase first."; return }
            switch departure {
            case .signOut:
                signedOutDestination = "Log in"
                clearActiveSession()
            case .deleteAccount:
                guard let identity else { return }
                signedOutDestination = "Welcome"
                removeCurrentAccount(identity: identity)
            }
            // Keep loading visible while the root swaps to a fresh welcome screen.
            try? await Task.sleep(nanoseconds: 650_000_000)
            if journal == nil {
                feedback = .init(title: departure == .deleteAccount ? "Account deleted" : "Signed out",
                    message: departure == .deleteAccount ? "Your account and its data have been removed from this device." : "You are signed out. Your saved messages will be here when you return to this account.")
            }
        }
    }

    private func clearActiveSession() {
        safetyRequest = nil
        coinSpendRequest = nil; coinShortfall = nil; requiresAppleProfileReview = false
        KokoLocalReminders.disable()
        UserDefaults.standard.removeObject(forKey: sessionPreference)
        journal = nil
        activeIdentity = nil
        storageUnavailable = false
    }

    private func removeCurrentAccount(identity: String) {
        if journal?.welcomeGiftGrantedAt != nil { UserDefaults.standard.set(true, forKey: "koko.firstVisitGift." + myID) }
        do {
            let verifier = try KokoLocalCredentials.verifier(for: identity)
            let accountFile = try journalURL(identity)
            let portraitURL = (journal?.member.portraitFileName).flatMap { KokoPortraitFiles.url(for: $0) }
            // Keep a rollback copy in memory until both account files are removed.
            let portraitBackup: Data?
            if let portraitURL, fileManager.fileExists(atPath: portraitURL.path) {
                portraitBackup = try Data(contentsOf: portraitURL)
            } else { portraitBackup = nil }
            try KokoLocalCredentials.remove(identity: identity)
            do {
                if let portraitURL, portraitBackup != nil { try fileManager.removeItem(at: portraitURL) }
                try fileManager.removeItem(at: accountFile)
            }
            catch {
                if let portraitURL, let portraitBackup {
                    try? portraitBackup.write(to: portraitURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                }
                if let verifier { try? KokoLocalCredentials.save(verifier, identity: identity) }
                throw error
            }
            if let subject = journal?.appleSubjectIdentifier { UserDefaults.standard.removeObject(forKey: "koko.appleName." + KokoLocalCredentials.identityKey(subject)) }
            clearActiveSession()
        }
        catch { notice = "Your account could not be deleted. Please try again." }
    }
    func saveProfile(_ member: CommunityMember, portraitJPEG: Data? = nil) -> Bool {
        guard hasCurrentPolicyConsent else { notice = "Agree to the current Terms of Service and Privacy Policy first."; return false }
        if let issue = KokoAccountValidation.profileIssue(member) { notice = issue; return false }
        var revised = member
        var newPortrait: String?
        let oldPortrait = currentMember?.portraitFileName
        do {
            if let portraitJPEG { newPortrait = try KokoPortraitFiles.save(portraitJPEG); revised.portraitFileName = newPortrait; revised.suppliedPortraitPhotoKey = nil }
            if update({ $0.member = revised; $0.completedProfile = true }) {
                requiresAppleProfileReview = false
                if let oldPortrait, oldPortrait != revised.portraitFileName { KokoPortraitFiles.remove(oldPortrait) }
                return true
            }
        } catch { notice = "Your photo could not be saved. Please try again." }
        if let newPortrait { KokoPortraitFiles.remove(newPortrait) }
        return false
    }
    func toggleFollow(_ memberID: String) {
        guard accountDeparture == nil, memberID != myID,
              isMemberVisible(memberID),
              !(journal?.blockedMembers.contains(memberID) ?? false) else { return }
        update { if $0.followedMembers.contains(memberID) { $0.followedMembers.remove(memberID) } else { $0.followedMembers.insert(memberID) } }
    }

    func conversation(for memberID: String) -> PrivateConversation? { conversations.first { $0.correspondentID == memberID } }
    @discardableResult
    func saveDraft(_ text: String, memberID: String, photoKey: String? = nil) -> Bool {
        guard accountDeparture == nil, !isContentHidden("conversation-" + memberID), memberID != myID, members.contains(where: { $0.id == memberID }),
              photoKey == nil || KokoMediaLibrary.asset(photoKey)?.isVideo == false else { return false }
        guard conversation(for: memberID) != nil || !text.isEmpty || photoKey != nil else { return true }
        return update {
            if let index = $0.privateConversations.firstIndex(where: { $0.correspondentID == memberID }) {
                $0.privateConversations[index].compositionDraft = String(text.prefix(2000))
                $0.privateConversations[index].compositionPhotoDraft = photoKey
            } else {
                $0.privateConversations.append(.init(id: UUID().uuidString, correspondentID: memberID, entries: [],
                                                     compositionDraft: String(text.prefix(2000)), compositionPhotoDraft: photoKey))
            }
        }
    }
    func sendMessage(_ text: String, memberID: String, attachment: Int? = nil, photoKey: String? = nil) -> Bool {
        guard requireMutualConnection(memberID) else { return false }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard acceptsCommunityText(trimmed) else { return false }
        let photo = KokoMediaLibrary.asset(photoKey)
        guard photoKey == nil || photo?.isVideo == false else { notice = "Choose a photo from the collection."; return false }
        guard attachment != nil || photo != nil || !trimmed.isEmpty else { return false }
        let entry = ConversationEntry(authorMemberID: myID, messageText: String(trimmed.prefix(2000)), attachmentTile: attachment, attachmentPhotoKey: photoKey)
        return update {
            if let index = $0.privateConversations.firstIndex(where: { $0.correspondentID == memberID }) {
                $0.privateConversations[index].entries.append(entry)
                $0.privateConversations[index].compositionDraft = ""
                $0.privateConversations[index].compositionPhotoDraft = nil
            } else { $0.privateConversations.append(.init(id: UUID().uuidString, correspondentID: memberID, entries: [entry])) }
        }
    }
    func checkIn() {
        guard !checkedInToday else { notice = "You're already checked in today."; return }
        let key = todayKey
        if update({ $0.checkInDayKeys.insert(key) }) { notice = "Checked in. 10 activity points added on this device." }
    }
    func saveRoom(_ room: HostedConversationRoom, creating: Bool = false) -> Bool {
        let previous = self.room(room.id)
        let roomText = [(room.roomTitle, previous?.roomTitle), (room.conversationPrompt, previous?.conversationPrompt), (room.hostNote, previous?.hostNote)]
            .filter { $0.0 != $0.1 }.map { $0.0 }
        let previousEntryIDs = Set(previous?.roomConversation.map(\.id) ?? [])
        let newMessages = room.roomConversation.filter { !previousEntryIDs.contains($0.id) }.map(\.messageText)
        guard (roomText + newMessages).allSatisfy({ acceptsCommunityText($0) }) else { return false }
        return update { if creating { $0.createdRooms.append(room) } else { $0.roomOverrides[room.id] = room } }
    }
    func leaveSeat(in roomID: String) {
        guard var room = room(roomID) else { return }
        guard room.hostMemberID != myID else { return }
        let departingSeats = room.seatAssignments.filter { $0.value == myID }.map(\.key)
        room.seatAssignments = room.seatAssignments.filter { $0.value != myID }
        room.mutedSeatNumbers.subtract(departingSeats)
        _ = saveRoom(room)
    }
    @discardableResult
    func block(_ memberID: String) -> Bool {
        guard memberID != myID, member(memberID) != nil else { return false }
        let saved = update {
            $0.blockedMembers.insert(memberID)
            $0.followedMembers.remove(memberID)
            $0.confirmedFollowerIDs?.remove(memberID)
        }
        if saved { feedback = .init(title: "Person blocked", message: "Their profile, posts, comments, rooms and conversations are now hidden on this device.") }
        return saved
    }
    @discardableResult
    func report(_ reportedContentID: String, reason: String) -> Bool {
        guard !reportedContentID.isEmpty, KokoSafetyReason.all.contains(reason) else { return false }
        let saved = update {
            $0.safetyRecords.append(.init(reportedContentID: reportedContentID, reportReason: reason))
            $0.hiddenContentKeys.insert(reportedContentID)
        }
        if saved { feedback = .init(title: "Report saved", message: "This content is hidden. Your report is saved on this device; a moderation service is not connected yet.") }
        return saved
    }
    @discardableResult
    func unblock(_ memberID: String) -> Bool {
        let saved = update { $0.blockedMembers.remove(memberID) }
        if saved { feedback = .init(title: "Person unblocked", message: "Their content can appear again. Neither follow nor friendship is restored automatically.") }
        return saved
    }
    func clearTransientCache() {
        do {
            let cache = try fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("KokoMedia")
            if fileManager.fileExists(atPath: cache.path) { try fileManager.removeItem(at: cache) }
            notice = "Media cache cleared. Your profile, conversations and keepsakes are preserved."
        } catch { notice = "The media cache couldn't be cleared. Please try again." }
    }
}
