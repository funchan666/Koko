import SwiftUI

@MainActor
final class KokoRoomDemoSession: ObservableObject {
    @Published private(set) var entries: [ConversationEntry] = []
    @Published private(set) var audienceIDs: [String] = []
    @Published private(set) var speakingMemberID: String?
    private var sequence = 0
    private var activeRoomID: String?

    func audience(in community: CommunityJournalStore) -> [CommunityMember] {
        audienceIDs.filter(community.isMemberVisible).compactMap(community.member)
    }

    func stageRoom(_ room: HostedConversationRoom, in community: CommunityJournalStore) -> HostedConversationRoom {
        var stage = room
        stage.roomConversation = (room.roomConversation + entries.filter(community.isEntryVisible))
            .sorted { $0.postedAt < $1.postedAt }
        return stage
    }

    func pause() { speakingMemberID = nil }

    func run(room: HostedConversationRoom, community: CommunityJournalStore) async {
        let isCatalogueRoom = KokoCommunity.rooms.contains { $0.id == room.id }
        if activeRoomID != room.id {
            activeRoomID = room.id
            entries = []
            sequence = 0
            let configured = [room.hostMemberID] + room.seatAssignments.sorted { $0.key < $1.key }.map(\.value)
            var uniqueIDs = Set<String>()
            audienceIDs = (configured + [community.myID]).filter { uniqueIDs.insert($0).inserted }
        }
        if !isCatalogueRoom { audienceIDs = [community.myID]; return }
        while !Task.isCancelled {
            do { try await Task.sleep(nanoseconds: sequence == 0 ? 700_000_000 : UInt64([2.8, 3.6, 2.4, 4.2][sequence % 4] * 1_000_000_000)) }
            catch { return }
            guard !Task.isCancelled, let currentRoom = community.room(room.id) else { return }
            audienceIDs.removeAll { !community.isMemberVisible($0) }
            let available = community.members.map(\.id)
            if sequence % 3 == 0, let arriving = available.first(where: { !audienceIDs.contains($0) }) {
                audienceIDs.append(arriving)
            } else if sequence % 7 == 6, let departing = audienceIDs.last(where: {
                $0 != community.myID && $0 != currentRoom.hostMemberID && !currentRoom.seatAssignments.values.contains($0)
            }) {
                audienceIDs.removeAll { $0 == departing }
            }
            let senders = audienceIDs.filter { $0 != community.myID && community.isMemberVisible($0) }
            guard !senders.isEmpty else { sequence += 1; continue }
            let sender = senders[sequence % senders.count]
            let phrases = Self.phrases(for: currentRoom.conversationTopic)
            guard !phrases.isEmpty else { sequence += 1; continue }
            var entry = ConversationEntry(authorMemberID: sender, messageText: KokoCopy.text(phrases[sequence % phrases.count]))
            entry.id = "room-demo-\(room.id)-\(sender)-\(sequence)"
            if sequence % 4 == 2, !KokoCommunity.keepsakes.isEmpty {
                let gift = KokoCommunity.keepsakes[(sequence / 4) % KokoCommunity.keepsakes.count]
                let quantity = [1, 3, 1, 5][(sequence / 4) % 4]
                entry.id += "-gift"
                entry.attachmentTile = gift.artworkTile
                entry.messageText = KokoCopy.text(gift.keepsakeName) + " ×\(quantity)"
            }
            entries.removeAll { $0.id == entry.id || !community.isEntryVisible($0) }
            if community.isEntryVisible(entry) { entries.append(entry) }
            entries = Array(entries.suffix(36))
            let speakers = currentRoom.seatAssignments.sorted { $0.key < $1.key }
                .filter { !currentRoom.mutedSeatNumbers.contains($0.key) && $0.value != community.myID && community.isMemberVisible($0.value) }
                .map(\.value)
            speakingMemberID = speakers.isEmpty || sequence % 5 == 4 ? nil : speakers[sequence % speakers.count]
            sequence += 1
        }
    }

    private static func phrases(for topic: String) -> [String] {
        let phrases = KokoCommunityCollection.shared.snapshot.arrangement.roomPhrases
        return phrases[topic] ?? phrases["Conversation"] ?? []
    }
}

struct KokoRoomAudienceButton: View {
    let members: [CommunityMember]
    let open: () -> Void
    var body: some View {
        Button(action: open) {
            HStack(spacing: 7) {
                HStack(spacing: -7) {
                    ForEach(Array(members.prefix(3))) { member in
                        KokoMemberPortrait(member: member).frame(width: 23, height: 23).clipShape(Circle())
                    }
                }.accessibilityHidden(true)
                Text("\(members.count) online").font(KokoTypography.emphasis(size: 11)).lineLimit(1)
            }.padding(.horizontal, 11).frame(minHeight: 44)
                .background(KokoControlSurface()).contentShape(Rectangle())
        }.buttonStyle(KokoPressStyle()).accessibilityHint("View room audience")
    }
}
