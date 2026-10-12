import Foundation

struct ConversationRunSheet: Identifiable, Codable, Hashable {
    var id = UUID().uuidString
    var sessionTitle: String
    var orderedPrompts: [String]
    var listeningNotes: [String] = ["", "", ""]
    var activePromptIndex = 0
    var linkedRoomID: String?
    var hostingStartedAt: Date?
    var hostingFinishedAt: Date?
    var personalReflection = ""
    var followUpPrompt = ""
    var lastEditedAt = Date()
    var isActive: Bool { hostingStartedAt != nil && hostingFinishedAt == nil }
    static let stages = ["Open the circle", "Go a little deeper", "Leave a thread"]
    private enum CodingKeys: String, CodingKey {
        case id
        case sessionTitle = "title"
        case orderedPrompts = "questions"
        case listeningNotes = "notes"
        case activePromptIndex = "currentStep"
        case linkedRoomID = "roomID"
        case hostingStartedAt = "startedAt"
        case hostingFinishedAt = "finishedAt"
        case personalReflection = "reflection"
        case followUpPrompt = "nextConversation"
        case lastEditedAt = "updatedAt"
    }
}

enum ConversationEditions {
    static let musicEditionID = "music-memories-v1"
    static let musicPrice = 80
    static let everyday = [
        "What small moment made you pause today?",
        "What did that moment change about the way you felt?",
        "What would you like to ask each other next time?"
    ]
    static let music = [
        "Which song takes you back to a particular room?",
        "Who was there, and what do you remember beyond the music?",
        "Which song would you leave for that person today?",
        "Which song did someone introduce you to?",
        "How has the meaning of that song changed for you?",
        "What story would you share before playing your next song?"
    ]
}
