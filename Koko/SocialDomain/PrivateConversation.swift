import Foundation

struct PrivateConversation: Identifiable, Codable, Hashable {
    var id: String
    var correspondentID: String
    var entries: [ConversationEntry]
    var unreadEntries: Int = 0
    var compositionDraft: String = ""
    var compositionPhotoDraft: String? = nil
}
