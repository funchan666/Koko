import Foundation

struct RoomKeepsake: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let keepsakeName: String
    let artworkTile: Int
    let coinPrice: Int
    let wearable: Bool
    private enum CodingKeys: String, CodingKey {
        case id
        case keepsakeName
        case artworkTile
        case coinPrice = "tokenCost"
        case wearable
    }
}
