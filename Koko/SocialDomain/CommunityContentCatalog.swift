import Foundation

@MainActor
enum KokoCommunity {
    static var topics: [String] { KokoCommunityCollection.shared.snapshot.arrangement.topics }
    static var members: [CommunityMember] { KokoCommunityCollection.shared.snapshot.members }
    static var rooms: [HostedConversationRoom] { KokoCommunityCollection.shared.snapshot.rooms }
    static var moments: [SharedMoment] { KokoMediaLibrary.assets.map(\.moment) }
    static var keepsakes: [RoomKeepsake] { KokoCommunityCollection.shared.snapshot.keepsakes }
    static let previousVoiceRoomHosts = ["open-notebook": "ren", "between-songs": "marlowe"]
}
