import Foundation
import Combine

@MainActor
final class KokoCommunityCollection: ObservableObject {
    static let shared = KokoCommunityCollection()
    struct Arrangement: Decodable, Sendable {
        let topics: [String]
        let roomVideoKeys: [String: String]
        let coinPacks: [KokoCoinPack]
        let roomPhrases: [String: [String]]
    }
    struct Engagement: Decodable, Sendable {
        let id: String
        let likeCount: Int
        let comments: [ConversationEntry]
    }
    struct Collection {
        var members: [CommunityMember] = []
        var rooms: [HostedConversationRoom] = []
        var keepsakes: [RoomKeepsake] = []
        var media: [CommunityMediaAsset] = []
        var starters: [ConversationStarter] = []
        var engagement: [Engagement] = []
        var arrangement = Arrangement(topics: [], roomVideoKeys: [:], coinPacks: [], roomPhrases: [:])
    }
    @Published private(set) var snapshot = Collection()
    @Published private(set) var error: String?
    @Published private(set) var loading = false
    private var generation = UUID()
    func cancel() { generation = UUID(); loading = false }
    func load() async {
        let id = UUID(); generation = id; loading = true; error = nil
        do {
            async let members: [CommunityMember] = fetch(ConfiguredContentPaths.members)
            async let rooms: [HostedConversationRoom] = fetch(ConfiguredContentPaths.rooms)
            async let keepsakes: [RoomKeepsake] = fetch(ConfiguredContentPaths.keepsakes)
            async let media: [CommunityMediaAsset] = fetch(ConfiguredContentPaths.media)
            async let starters: [ConversationStarter] = fetch(ConfiguredContentPaths.starters)
            async let engagement: [Engagement] = fetch(ConfiguredContentPaths.engagement)
            async let arrangement: Arrangement = fetch(ConfiguredContentPaths.arrangement)
            let batch = try await Collection(members: members, rooms: rooms, keepsakes: keepsakes, media: media,
                                             starters: starters, engagement: engagement, arrangement: arrangement)
            try validate(batch)
            guard generation == id, !Task.isCancelled else { return }
            snapshot = batch; loading = false
        } catch {
            guard generation == id, !Task.isCancelled else { return }
            self.error = "The community collection could not be loaded. Please try again."; loading = false
        }
    }
    private func fetch<T: Decodable & Sendable>(_ path: String) async throws -> T {
        let response = try await KokoGatewayClient.shared.request(path)
        guard KokoGatewayClient.integer(response["code"]) == 0, let data = response["data"] else { throw KokoGatewayClient.Failure.content }
        return try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: data))
    }
    private func validate(_ batch: Collection) throws {
        func unique(_ ids: [String]) -> Bool { !ids.isEmpty && !ids.contains("") && Set(ids).count == ids.count }
        guard unique(batch.members.map(\.id)), unique(batch.rooms.map(\.id)), unique(batch.media.map(\.id)),
              unique(batch.keepsakes.map(\.id)), unique(batch.starters.map(\.id)), unique(batch.engagement.map(\.id)),
              unique(batch.arrangement.coinPacks.map(\.id)), unique(batch.arrangement.topics), unique(batch.media.map(\.momentKey)) else { throw KokoGatewayClient.Failure.content }
        let people = Set(batch.members.map(\.id)), media = Set(batch.media.map(\.id)), rooms = Set(batch.rooms.map(\.id))
        guard batch.rooms.allSatisfy({ room in
            people.contains(room.hostMemberID) && (1...12).contains(room.seatLimit)
                && room.seatAssignments.allSatisfy { $0.key >= 0 && $0.key < room.seatLimit && people.contains($0.value) }
                && room.moderatorMemberIDs.isSubset(of: people)
                && room.roomConversation.allSatisfy { people.contains($0.authorMemberID) }
                && batch.arrangement.topics.contains(room.conversationTopic)
        }),
              batch.members.allSatisfy({ $0.suppliedPortraitPhotoKey.map(media.contains) ?? true }),
              batch.media.allSatisfy({ asset in
                  people.contains(asset.curatorMemberID) && ["photo", "video"].contains(asset.mediaKind)
                      && ["photos", "videos"].contains(asset.sourceFolder)
                      && asset.sourceFilename == (asset.sourceFilename as NSString).lastPathComponent
                      && asset.previewFilename == (asset.previewFilename as NSString).lastPathComponent
                      && asset.sourceURL != nil && asset.previewURL != nil && asset.imageURL != nil
              }),
              batch.arrangement.roomVideoKeys.allSatisfy({ room, asset in rooms.contains(room) && batch.media.contains { $0.id == asset && $0.isVideo } }) else { throw KokoGatewayClient.Failure.content }
        guard batch.engagement.allSatisfy({ item in batch.media.contains { $0.momentKey == item.id } && item.likeCount >= 0 && item.comments.allSatisfy { people.contains($0.authorMemberID) } }),
              batch.keepsakes.allSatisfy({ $0.coinPrice >= 0 }),
              batch.arrangement.coinPacks.allSatisfy({ $0.coinQuantity > 0 && Decimal(string: $0.referenceUSD) != nil }) else { throw KokoGatewayClient.Failure.content }
    }
}
