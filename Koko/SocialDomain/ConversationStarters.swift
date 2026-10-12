import Foundation

struct ConversationStarter: Identifiable, Hashable, Sendable {
    let id: String
    let topic: String
    let question: String
    let roomName: String

    static let collection: [ConversationStarter] = [
        .init(id: "small-joy", topic: "Conversation", question: "What small thing made your day better?", roomName: "Small joys"),
        .init(id: "unexpected-skill", topic: "Conversation", question: "What could you happily teach someone?", roomName: "Teach me something"),
        .init(id: "perfect-afternoon", topic: "Conversation", question: "What does your perfect slow afternoon look like?", roomName: "A slow afternoon"),
        .init(id: "song-memory", topic: "Music", question: "Which song takes you straight back to a memory?", roomName: "Songs with a story"),
        .init(id: "first-concert", topic: "Music", question: "Which artist would you love to hear live?", roomName: "Dream gig"),
        .init(id: "soundtrack", topic: "Music", question: "What song would open the movie of your life?", roomName: "Your opening track"),
        .init(id: "unfinished-project", topic: "Creative", question: "What are you making just for the joy of it?", roomName: "Made for the joy"),
        .init(id: "curiosity", topic: "Creative", question: "What would you try if being a beginner felt easy?", roomName: "Begin again"),
        .init(id: "inspiration", topic: "Creative", question: "Where do your best ideas usually find you?", roomName: "Where ideas happen"),
        .init(id: "unwind", topic: "After hours", question: "What helps you switch off after a long day?", roomName: "The wind-down"),
        .init(id: "night-snack", topic: "After hours", question: "What is your ideal late-night comfort food?", roomName: "Midnight menu"),
        .init(id: "weekend-plan", topic: "After hours", question: "What little adventure would you choose this weekend?", roomName: "Weekend daydreams")
    ]

    static func find(_ id: String?) -> ConversationStarter? {
        collection.first { $0.id == id }
    }
}

@MainActor
extension CommunityJournalStore {
    var savedConversationStarterIDs: Set<String> { journal?.savedConversationStarterIDs ?? [] }

    @discardableResult
    func toggleConversationStarter(_ id: String) -> Bool {
        guard ConversationStarter.find(id) != nil else { return false }
        return update {
            var saved = $0.savedConversationStarterIDs ?? []
            if saved.contains(id) { saved.remove(id) } else { saved.insert(id) }
            $0.savedConversationStarterIDs = saved
        }
    }

    @discardableResult
    func saveConversationAnswer(_ text: String, starterID: String) -> Bool {
        guard ConversationStarter.find(starterID) != nil else { return false }
        let answer = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answer.isEmpty, answer.count <= 240 else {
            notice = KokoCopy.text("Write an answer between 1 and 240 characters.")
            return false
        }
        guard acceptsCommunityText(answer) else { return false }
        return update {
            var answers = $0.member.conversationAnswers ?? [:]
            answers[starterID] = answer
            $0.member.conversationAnswers = answers
        }
    }

    @discardableResult
    func removeConversationAnswer(_ starterID: String) -> Bool {
        update { $0.member.conversationAnswers?.removeValue(forKey: starterID) }
    }

    /// Appends to the existing draft; the user still reviews and explicitly sends it.
    func prepareConversationStarter(_ starterID: String, for memberID: String) -> Bool {
        guard requireMutualConnection(memberID) else { return false }
        guard let starter = ConversationStarter.find(starterID), friends.contains(memberID),
              members.contains(where: { $0.id == memberID }) else {
            notice = KokoCopy.text("Choose a mutual friend to start this conversation.")
            return false
        }
        let question = KokoCopy.text(starter.question)
        let previous = conversation(for: memberID)?.compositionDraft ?? ""
        let draft = previous.isEmpty ? question : previous + "\n\n" + question
        guard draft.count <= 2000 else {
            notice = KokoCopy.text("Your draft is full. Shorten it before adding a question.")
            return false
        }
        return update {
            if let index = $0.privateConversations.firstIndex(where: { $0.correspondentID == memberID }) {
                $0.privateConversations[index].compositionDraft = draft
            } else {
                $0.privateConversations.append(.init(id: UUID().uuidString, correspondentID: memberID,
                                                     entries: [], compositionDraft: draft))
            }
        }
    }

    func sharedInterests(with member: CommunityMember) -> [String] {
        let mine = Set(currentMember?.interests ?? [])
        return member.interests.filter { mine.contains($0) }
    }
}
