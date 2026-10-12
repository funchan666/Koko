import Foundation
import CryptoKit
import Ably

@MainActor
final class KokoRoomBulletins {
    struct Bulletin: Codable, Equatable {
        let msgId: String
        let occasion: String
        let sentAt: Int64
        let expiresAt: Int64
        let headline: String
        let explanation: String
    }
    struct Receipt: Codable {
        let receiptId: String
        let msgId: String
        let capability: String
        let state: String
        let extra: Stage
        struct Stage: Codable { let stage: String; let sequence: Int }
    }
    struct Archive: Codable {
        var messages: [String: Bulletin] = [:]
        var stages: [String: Int] = [:]
        var receipts: [String: Receipt] = [:]
    }
    var onPresent: ((Bulletin) -> Bool)?
    private var presentedIDs = Set<String>()
    private var archive = Archive()
    private var url: URL?
    private var scope: String?
    private var enabled = false
    private var retry: Task<Void, Never>?
    private weak var community: CommunityJournalStore?
    private weak var transport: ConfiguredRealtimeTransport?
    func start(channel: String, community: CommunityJournalStore, transport: ConfiguredRealtimeTransport) {
        stop()
        self.community = community; self.transport = transport; presentedIDs = []
        let scope = (IntegrationContract.baseURLString ?? "") + "|" + channel
        self.scope = scope
        let key = SHA256.hash(data: Data(scope.utf8)).map { String(format: "%02x", $0) }.joined()
        url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("KokoRoomBulletins").appendingPathComponent(key + ".json")
        do {
            if let url, FileManager.default.fileExists(atPath: url.path) { archive = try JSONDecoder().decode(Archive.self, from: Data(contentsOf: url)) }
            else { archive = Archive() }
            enabled = true
        } catch { enabled = false }
    }
    func stop() { retry?.cancel(); retry = nil; enabled = false; community = nil; transport = nil; scope = nil }
    func connected() {
        guard enabled else { return }
        applyPending(); flush(); sync()
        guard retry == nil else { return }
        retry = Task { [weak self] in
            for delay in [2, 4, 8, 16, 30] {
                do { try await Task.sleep(for: .seconds(delay)) } catch { return }
                self?.flush()
            }
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
                self?.applyPending(); self?.flush(); self?.sync()
            }
        }
    }
    func receive(_ message: ARTMessage) {
        guard enabled, let object = ConfiguredCoreEvent.normalizedObject(message.data),
              let kind = object["occasion"] as? String,
              message.clientId != IntegrationContract.ablyClientID,
              (message.clientId == nil || message.clientId == "" ? IntegrationContract.allowsMissingSender : IntegrationContract.serverClientIDs.contains(message.clientId!)) else { return }
        if kind == "KokoBulletinReceiptAccepted" {
            guard let id = object["receiptId"] as? String, archive.receipts[id] != nil else { return }
            var next = archive; next.receipts[id] = nil; _ = save(next); return
        }
        guard kind == "KokoRoomBulletin", let data = try? JSONSerialization.data(withJSONObject: object), data.count <= 16384,
              let bulletin = try? JSONDecoder().decode(Bulletin.self, from: data), !bulletin.msgId.isEmpty,
              bulletin.msgId.count <= 180, !bulletin.headline.isEmpty, bulletin.headline.count <= 160,
              bulletin.explanation.count <= 4000 else { return }
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        guard bulletin.sentAt <= now + 30_000, bulletin.sentAt > 0,
              bulletin.expiresAt > now, bulletin.expiresAt > bulletin.sentAt,
              bulletin.expiresAt - bulletin.sentAt <= 604_800_000 else { return }
        if let existing = archive.messages[bulletin.msgId] {
            guard existing == bulletin else { return }; applyPending(); flush(); return
        }
        guard archive.messages.count < 2000, archive.receipts.count < 6000 else { return }
        var next = archive; next.messages[bulletin.msgId] = bulletin
        enqueue(bulletin.msgId, stage: "received", sequence: 1, in: &next)
        guard save(next) else { return }; applyPending(); flush()
    }
    func applyPending() {
        guard enabled, let community, community.journal != nil else { return }
        for bulletin in archive.messages.values where (archive.stages[bulletin.msgId] ?? 0) < 2 {
            let id = "bulletin:" + bulletin.msgId
            let saved = community.update { journal in
                guard !journal.notices.contains(where: { $0.id == id }) else { return }
                var notice = CommunityNotice(headline: bulletin.headline, explanation: bulletin.explanation)
                notice.id = id; notice.createdAt = Date(timeIntervalSince1970: Double(bulletin.sentAt) / 1000)
                journal.notices.insert(notice, at: 0)
            }
            guard saved else { continue }
            var next = archive; enqueue(bulletin.msgId, stage: "applied", sequence: 2, in: &next)
            _ = save(next)
        }
        if let next = archive.messages.values.sorted(by: { $0.sentAt < $1.sentAt }).first(where: {
            (archive.stages[$0.msgId] ?? 0) == 2 && !presentedIDs.contains($0.msgId)
        }) {
            if onPresent?(next) == true { presentedIDs.insert(next.msgId) }
        }
        for notice in community.journal?.notices ?? [] where notice.hasBeenRead && notice.id.hasPrefix("bulletin:") {
            let id = String(notice.id.dropFirst(9))
            guard archive.messages[id] != nil, (archive.stages[id] ?? 0) < 4 else { continue }
            var next = archive; enqueue(id, stage: "read", sequence: 4, in: &next); _ = save(next)
        }
    }
    func displayed(_ id: String) {
        guard enabled, archive.messages[id] != nil, (archive.stages[id] ?? 0) == 2 else { return }
        var next = archive; enqueue(id, stage: "displayed", sequence: 3, in: &next)
        if save(next) { flush() }
    }
    private func enqueue(_ id: String, stage: String, sequence: Int, in next: inout Archive) {
        let receipt = Receipt(receiptId: UUID().uuidString, msgId: id, capability: "KokoRoomBulletin", state: "success", extra: .init(stage: stage, sequence: sequence))
        next.receipts[receipt.receiptId] = receipt; next.stages[id] = sequence
    }
    private func save(_ next: Archive) -> Bool {
        guard let url else { return false }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(next).write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
            archive = next; return true
        } catch { return false }
    }
    private func flush() {
        guard enabled else { return }
        for receipt in archive.receipts.values {
            guard let bytes = try? JSONEncoder().encode(receipt), let object = try? JSONSerialization.jsonObject(with: bytes) else { continue }
            transport?.publish(name: "KokoBulletinReceipt", payload: object) { _ in }
        }
    }
    private func sync() {
        guard enabled else { return }
        transport?.publish(name: "KokoBulletinCatchup", payload: ["requestId": UUID().uuidString, "protocol": 1,
            "supportedEvents": ["KokoRoomBulletin"], "pendingMessageIds": archive.messages.keys.filter { (archive.stages[$0] ?? 0) < 2 }]) { _ in }
    }
}
