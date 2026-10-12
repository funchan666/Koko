import Foundation

struct HostedConversationRoom: Identifiable, Codable, Hashable {
    var id: String
    var roomTitle: String
    var conversationPrompt: String
    var hostMemberID: String
    var conversationTopic: String
    var seatLimit: Int
    var isPublicRoom: Bool
    var isVideoStage: Bool
    var artworkTile: Int
    var audienceGoal: Int
    var seatAssignments: [Int: String] = [:]
    var mutedSeatNumbers: Set<Int> = []
    var roomConversation: [ConversationEntry] = []
    var hostNote: String = "Make space for every voice."
    var moderatorMemberIDs: Set<String> = []
    private enum CodingKeys: String, CodingKey {
        case id
        case roomTitle
        case conversationPrompt
        case hostMemberID
        case conversationTopic
        case seatLimit
        case isPublicRoom
        case isVideoStage
        case artworkTile
        case audienceGoal = "targetAudience"
        case seatAssignments
        case mutedSeatNumbers
        case roomConversation
        case hostNote
        case moderatorMemberIDs
    }
}
