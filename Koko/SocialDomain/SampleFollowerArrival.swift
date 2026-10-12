import Foundation

struct SampleFollowerArrival: Codable {
    var memberID: String
    var scheduledAt: Date
    // A skipped arrival (for example, after blocking) is also resolved permanently.
    var resolvedAt: Date? = nil
}
