import Foundation

struct ConversationStarter: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let topic: String
    let question: String
    let roomName: String

    @MainActor static var collection: [ConversationStarter] { KokoCommunityCollection.shared.snapshot.starters }

    @MainActor static func find(_ id: String?) -> ConversationStarter? {
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
