import Foundation

struct CommunityNotice: Identifiable, Codable, Hashable {
    var id = UUID().uuidString
    var headline: String
    var explanation: String
    var hasBeenRead = false
    var createdAt = Date()
    var sampleFollowerID: String? = nil
}
