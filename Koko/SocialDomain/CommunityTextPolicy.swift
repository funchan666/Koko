import Foundation

enum CommunityTextPolicy {
    static let revisionMessage = "Please revise this text. Explicit sexual requests, paid sexual services and threats are not allowed."
    private static let disallowedPhrases = [
        "send me nudes", "send nudes", "sex for money", "paid sex", "buy sexual services", "i will kill you",
        "发裸照给我", "给我发裸照", "有偿性服务", "我要杀了你",
        "envíame desnudos", "sexo por dinero", "te voy a matar",
        "envoie moi des nudes", "sexe contre argent", "je vais te tuer",
        "裸の写真を送って", "有料の性的サービス", "お前を殺す"
    ].map(normalized)

    static func allows(_ text: String) -> Bool {
        let value = " " + normalized(text) + " "
        return !disallowedPhrases.contains { phrase in
            phrase.contains(" ") ? value.contains(" " + phrase + " ") : value.contains(phrase)
        }
    }

    private static func normalized(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        return folded.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ")
    }
}

@MainActor
extension CommunityJournalStore {
    @discardableResult
    func acceptsCommunityText(_ text: String) -> Bool {
        guard CommunityTextPolicy.allows(text) else { notice = CommunityTextPolicy.revisionMessage; return false }
        return true
    }
}
