import Foundation

struct SampleFollowerArrival: Codable {
    var memberID: String
    var scheduledAt: Date
    var resolvedAt: Date? = nil
}
