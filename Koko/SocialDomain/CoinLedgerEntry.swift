import Foundation

struct CoinLedgerEntry: Identifiable, Codable, Hashable {
    var id = UUID().uuidString
    var entryDescription: String
    var coinDelta: Int
    var recordedAt = Date()
    private enum CodingKeys: String, CodingKey {
        case id
        case entryDescription = "detailLine"
        case coinDelta = "tokenChange"
        case recordedAt
    }
}
