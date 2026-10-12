import Foundation

struct ConversationEntry: Identifiable, Codable, Hashable {
    var id = UUID().uuidString
    var authorMemberID: String
    var messageText: String
    var postedAt = Date()
    var attachmentTile: Int? = nil
    var attachmentPhotoKey: String? = nil
}
