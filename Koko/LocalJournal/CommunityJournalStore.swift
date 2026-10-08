import Foundation
import CryptoKit
import Combine

@MainActor
final class CommunityJournalStore: ObservableObject {
    @Published private(set) var journal: PersonalJournal?
    @Published var notice: String?
    @Published private(set) var storageUnavailable = false
    @Published var coinSpendRequest: CoinSpendRequest?
    @Published var coinShortfall: CoinShortfall?
    @Published var purchaseInProgress = false
    private var activeIdentity: String?
    private let fileManager = FileManager.default
    private let sessionPreference = "koko.activeLocalIdentity"

    init() {
        if let savedIdentity = UserDefaults.standard.string(forKey: sessionPreference) {
            do {
                let data = try Data(contentsOf: journalURL(savedIdentity))
                journal = try JSONDecoder().decode(PersonalJournal.self, from: data)
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
    var followers: Set<String> { journal?.sampleFollowers ?? [] }
    var friends: Set<String> { following.intersection(followers).subtracting(journal?.blockedMembers ?? []) }
    var members: [CommunityMember] {
        KokoCommunity.members.filter { !(journal?.blockedMembers.contains($0.id) ?? false) && !(journal?.hiddenContentKeys.contains($0.id) ?? false) }
    }
    var rooms: [ListeningRoom] {
        (KokoCommunity.rooms + (journal?.createdRooms ?? [])).map { journal?.roomOverrides[$0.id] ?? $0 }
            .filter { !(journal?.blockedMembers.contains($0.hostMemberID) ?? false) && !(journal?.hiddenContentKeys.contains($0.id) ?? false) }
            .map { room in
                var visible = room
                visible.seatAssignments = room.seatAssignments.filter { !(journal?.blockedMembers.contains($0.value) ?? false) }
                visible.roomConversation = room.roomConversation.filter { !(journal?.blockedMembers.contains($0.authorMemberID) ?? false) }
                return visible
            }
    }
    var moments: [SharedMoment] {
        KokoCommunity.moments.filter { !(journal?.hiddenContentKeys.contains($0.id) ?? false) && !(journal?.blockedMembers.contains($0.creatorMemberID) ?? false) }
    }
    var conversations: [PrivateConversation] {
        (journal?.privateConversations ?? []).filter { !(journal?.blockedMembers.contains($0.correspondentID) ?? false) }
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
    func room(_ identifier: String) -> ListeningRoom? { rooms.first { $0.id == identifier } }
    func signIn(email: String, password: String) -> Bool {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.range(of: #"^[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}$"#, options: .caseInsensitive) != nil,
              normalized.count <= 254, (8...128).contains(password.count) else {
            notice = "Enter a valid email and a password between 8 and 128 characters. This is a local preview; no email is sent."
            return false
        }
        return enterLocalIdentity("email:" + normalized)
    }
    func enterAppleIdentity(_ identifier: String, givenName: String?) -> Bool {
        enterLocalIdentity("apple:" + identifier, displayName: givenName)
    }
    private func enterLocalIdentity(_ identity: String, displayName: String? = nil) -> Bool {
        let key = SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
        do {
            let url = try journalURL(key)
            var restored: PersonalJournal
            if fileManager.fileExists(atPath: url.path) {
                restored = try JSONDecoder().decode(PersonalJournal.self, from: Data(contentsOf: url))
            } else {
                restored = PersonalJournal(member: .init(id: key, publicName: displayName ?? "Your name", hometownLabel: "", spokenLanguage: "English", adultAge: 25, genderLabel: "Prefer not to say", introductionLine: "", portraitTile: 0, interests: []))
                var newJournal = restored
                newJournal.welcomeGiftEligible = !UserDefaults.standard.bool(forKey: "koko.firstVisitGift." + key)
                try persist(newJournal, identity: key)
                restored = newJournal
            }
            activeIdentity = key
            journal = restored
            storageUnavailable = false
            UserDefaults.standard.set(key, forKey: sessionPreference)
            return true
        } catch {
            notice = "Your local profile couldn't be opened. Existing data has been kept."
            return false
        }
    }
    @discardableResult
    func update(_ change: (inout PersonalJournal) -> Void) -> Bool {
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
    private func persist(_ value: PersonalJournal, identity: String) throws {
        let data = try JSONEncoder().encode(value)
        try data.write(to: journalURL(identity), options: [.atomic, .completeFileProtectionUnlessOpen])
    }
    func signOut() {
        guard !purchaseInProgress else { notice = "Please finish or cancel the Apple purchase before switching accounts."; return }
        coinSpendRequest = nil; coinShortfall = nil
        KokoLocalReminders.disable()
        journal = nil
        activeIdentity = nil
        UserDefaults.standard.removeObject(forKey: sessionPreference)
    }
    func deleteLocalAccount() {
        guard !purchaseInProgress else { notice = "Please finish or cancel the Apple purchase first."; return }
        guard let identity = activeIdentity else { return }
        do { try fileManager.removeItem(at: journalURL(identity)); signOut() }
        catch { notice = "Your profile could not be removed. Please try again." }
    }
    func saveProfile(_ member: CommunityMember) -> Bool {
        guard (18...99).contains(member.adultAge), !member.publicName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            notice = "Add a display name and an adult age from 18 to 99."; return false
        }
        return update { $0.member = member; $0.completedProfile = true }
    }
    func toggleFollow(_ memberID: String) {
        guard memberID != myID, !(journal?.blockedMembers.contains(memberID) ?? false) else { return }
        update { if $0.followedMembers.contains(memberID) { $0.followedMembers.remove(memberID) } else { $0.followedMembers.insert(memberID) } }
    }
    func enableSampleFriendship(_ memberID: String) {
        guard !(journal?.blockedMembers.contains(memberID) ?? false) else { return }
        update {
            $0.followedMembers.insert(memberID)
            $0.sampleFollowers.insert(memberID)
            if !$0.privateConversations.contains(where: { $0.correspondentID == memberID }) {
                $0.privateConversations.append(.init(id: UUID().uuidString, correspondentID: memberID, entries: []))
            }
            $0.notices.insert(.init(headline: "Sample friendship added", explanation: "This connection is for trying conversations on your device."), at: 0)
        }
    }
    func conversation(for memberID: String) -> PrivateConversation? { conversations.first { $0.correspondentID == memberID } }
    func saveDraft(_ text: String, memberID: String) {
        update {
            if let index = $0.privateConversations.firstIndex(where: { $0.correspondentID == memberID }) { $0.privateConversations[index].compositionDraft = String(text.prefix(2000)) }
            else { $0.privateConversations.append(.init(id: UUID().uuidString, correspondentID: memberID, entries: [], compositionDraft: String(text.prefix(2000)))) }
        }
    }
    func sendMessage(_ text: String, memberID: String, attachment: Int? = nil, photoKey: String? = nil) -> Bool {
        guard friends.contains(memberID) else { notice = "A mutual connection is needed. You can enable a clearly marked sample friendship from this profile."; return false }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let photo = KokoMediaLibrary.asset(photoKey)
        guard photoKey == nil || photo?.isVideo == false else { notice = "Choose a photo from the collection."; return false }
        guard attachment != nil || photo != nil || !trimmed.isEmpty else { return false }
        let entry = ConversationEntry(authorMemberID: myID, messageText: String(trimmed.prefix(2000)), attachmentTile: attachment, attachmentPhotoKey: photoKey)
        return update {
            if let index = $0.privateConversations.firstIndex(where: { $0.correspondentID == memberID }) {
                $0.privateConversations[index].entries.append(entry)
                $0.privateConversations[index].compositionDraft = ""
            } else { $0.privateConversations.append(.init(id: UUID().uuidString, correspondentID: memberID, entries: [entry])) }
        }
    }
    func checkIn() {
        guard !checkedInToday else { notice = "You're already checked in today."; return }
        let key = todayKey
        if update({ $0.checkInDayKeys.insert(key) }) { notice = "Checked in. 10 activity points added on this device." }
    }
    func saveRoom(_ room: ListeningRoom, creating: Bool = false) -> Bool {
        update { if creating { $0.createdRooms.append(room) } else { $0.roomOverrides[room.id] = room } }
    }
    func leaveSeat(in roomID: String) {
        guard var room = room(roomID) else { return }
        guard room.hostMemberID != myID else { return }
        room.seatAssignments = room.seatAssignments.filter { $0.value != myID }
        saveRoom(room)
    }
    func block(_ memberID: String) {
        guard memberID != myID else { return }
        update { $0.blockedMembers.insert(memberID); $0.followedMembers.remove(memberID); $0.sampleFollowers.remove(memberID) }
    }
    func report(_ subjectKey: String, reason: String) {
        if update({ $0.safetyRecords.append(.init(subjectKey: subjectKey, selectedReason: reason)); $0.hiddenContentKeys.insert(subjectKey) }) {
            notice = "Hidden on this device. Your report is saved locally; it has not been sent to a moderation service."
        }
    }
    func clearTransientCache() {
        do {
            let cache = try fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("KokoMedia")
            if fileManager.fileExists(atPath: cache.path) { try fileManager.removeItem(at: cache) }
            notice = "Media cache cleared. Your profile, conversations and keepsakes are preserved."
        } catch { notice = "The media cache couldn't be cleared. Please try again." }
    }
}
