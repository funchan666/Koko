import Foundation

struct SharedMoment: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var creatorMemberID: String
    var captionLine: String
    var topicLabel: String
    var coverTile: Int
    var bundledMovieName: String?
    var libraryAssetKey: String? = nil
}
