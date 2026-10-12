import Foundation

@MainActor
enum KokoMomentConversationSeeds {
    static func comments(for momentID: String) -> [ConversationEntry] {
        KokoCommunityCollection.shared.snapshot.engagement.first { $0.id == momentID }?.comments ?? []
    }
    static func likeCount(for momentID: String) -> Int {
        KokoCommunityCollection.shared.snapshot.engagement.first { $0.id == momentID }?.likeCount ?? 0
    }
}
