import Foundation

struct KokoRoomOrder: Codable, Identifiable {
    enum State: String, Codable { case prepared, awaitingApple, purchased, confirmed, finished, cancelled }
    let id: UUID
    let eventID: String
    let orderReference: String
    let productID: String
    let ownerID: String
    let accountToken: UUID?
    let installationID: String
    let edition: String
    let origin: String
    let settlementPath: String
    let editionField: String
    let installationField: String
    let transactionField: String
    let receiptField: String
    let orderField: String
    let createdAt: Date
    var state: State
    var transactionID: String?
}

@MainActor
final class KokoRoomOrderJournal {
    private(set) var orders: [KokoRoomOrder] = []
    private(set) var available = false
    private(set) var failure: String?
    private let url: URL?
    init() {
        url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("KokoCommerce", isDirectory: true).appendingPathComponent("room-orders.json")
        do {
            guard let url else { throw KokoGatewayClient.Failure.installation }
            if FileManager.default.fileExists(atPath: url.path) { orders = try JSONDecoder().decode([KokoRoomOrder].self, from: Data(contentsOf: url)) }
            available = true
        } catch { failure = "Your pending orders could not be read. They have been kept for recovery." }
    }
    func save(_ order: KokoRoomOrder) throws {
        guard available, let url else { throw KokoGatewayClient.Failure.installation }
        var next = orders
        if let index = next.firstIndex(where: { $0.id == order.id }) { next[index] = order } else { next.append(order) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let bytes = try JSONEncoder().encode(next)
        try bytes.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
        orders = next
    }
    func boundOrder(transaction: String, token: UUID?) -> KokoRoomOrder? {
        orders.first { $0.transactionID == transaction || ($0.accountToken == nil && $0.id == token) }
    }
    func requiresOrderReview(product: String, token: UUID?) -> Bool {
        orders.contains {
            $0.accountToken == token && $0.productID == product && $0.transactionID == nil && $0.state == .awaitingApple
        }
    }
    func quarantine(transaction: String, product: String, token: UUID?) {
        guard let url else { return }
        let file = url.deletingLastPathComponent().appendingPathComponent("unmatched-transactions.json")
        do {
            var values: [String: [String: String]] = [:]
            if FileManager.default.fileExists(atPath: file.path) { values = try JSONDecoder().decode([String: [String: String]].self, from: Data(contentsOf: file)) }
            values[transaction] = ["product": product, "accountToken": token?.uuidString ?? "", "recordedAt": ISO8601DateFormatter().string(from: Date())]
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(values).write(to: file, options: [.atomic, .completeFileProtectionUnlessOpen])
        } catch { failure = "An unfinished purchase could not be saved for recovery." }
    }
}
