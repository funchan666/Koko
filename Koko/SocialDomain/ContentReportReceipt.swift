import Foundation

struct ContentReportReceipt: Identifiable, Codable, Hashable {
    var id = UUID().uuidString
    var reportedContentID: String
    var reportReason: String
    var recordedAt = Date()
    private enum CodingKeys: String, CodingKey {
        case id
        case reportedContentID = "subjectKey"
        case reportReason = "selectedReason"
        case recordedAt
    }
}
