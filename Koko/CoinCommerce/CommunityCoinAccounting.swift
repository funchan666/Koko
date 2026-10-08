import Foundation
import CryptoKit

@MainActor
extension CommunityJournalStore {
    var coinBalance: Int { max(0, journal?.coinBalance ?? 0) }
    var coinAdjustmentDue: Int { max(0, -(journal?.coinBalance ?? 0)) }
    var welcomeGiftNeedsPresentation: Bool {
        journal?.completedProfile == true && journal?.welcomeGiftGrantedAt != nil && journal?.welcomeGiftAcknowledged != true
    }
    var purchaseAccountToken: UUID? {
        guard journal != nil else { return nil }
        let digest = SHA256.hash(data: Data(("koko.coin-owner.v1:" + myID).utf8))
        let hex = digest.prefix(16).map { String(format: "%02x", $0) }.joined()
        let groups = [0..<8, 8..<12, 12..<16, 16..<20, 20..<32].map { range in
            String(hex[hex.index(hex.startIndex, offsetBy: range.lowerBound)..<hex.index(hex.startIndex, offsetBy: range.upperBound)])
        }
        return UUID(uuidString: groups.joined(separator: "-"))
    }

    @discardableResult
    func prepareCoinWallet() -> Bool {
        guard journal != nil else { return false }
        guard journal?.coinBalance == nil else { return true }
        return update {
            $0.coinBalance = 0
            $0.verifiedCoinCredits = [:]
            // Do not convert earlier freely refillable demo balances into the Apple wallet.
            $0.archivedDemoCoinBalance = $0.demoTokenBalance
            $0.archivedDemoWalletHistory = $0.walletHistory
            $0.walletHistory = []
            $0.demoTokenBalance = 0
        }
    }

    func welcomeOnFirstHomeVisit() {
        guard journal?.completedProfile == true, prepareCoinWallet(),
              journal?.welcomeGiftEligible == true, journal?.welcomeGiftGrantedAt == nil else { return }
        if update({
            $0.coinBalance = ($0.coinBalance ?? 0) + KokoCoinCatalog.firstVisitGift
            $0.welcomeGiftGrantedAt = Date()
            $0.welcomeGiftEligible = false
            $0.walletHistory.insert(.init(detailLine: "Your first record · welcome gift", tokenChange: KokoCoinCatalog.firstVisitGift), at: 0)
        }) { UserDefaults.standard.set(true, forKey: "koko.firstVisitGift." + myID) }
    }
    func acknowledgeWelcomeGift() { update { $0.welcomeGiftAcknowledged = true } }

    /// Apple signature and ownership checks happen before this method. Credit and deduplication share one atomic write.
    func recordVerifiedPurchase(_ credit: VerifiedCoinCredit, ownerToken: UUID) -> Bool {
        guard purchaseAccountToken == ownerToken, prepareCoinWallet() else { return false }
        guard journal?.verifiedCoinCredits?[credit.appleTransactionID] == nil,
              journal?.revokedCoinTransactions?.contains(credit.appleTransactionID) != true else { return true }
        guard credit.creditedCoins > 0,
              (journal?.coinBalance ?? 0) <= Int.max - credit.creditedCoins else {
            notice = "This coin balance cannot be updated yet. Your Apple order remains unfinished."; return false
        }
        return update {
            $0.coinBalance = ($0.coinBalance ?? 0) + credit.creditedCoins
            if $0.verifiedCoinCredits == nil { $0.verifiedCoinCredits = [:] }
            $0.verifiedCoinCredits?[credit.appleTransactionID] = credit
            $0.walletHistory.insert(.init(detailLine: "Apple coin pack · " + credit.storeEnvironment, tokenChange: credit.creditedCoins), at: 0)
        }
    }

    func recordPurchaseRevocation(transactionID: String, revokedAt: Date, ownerToken: UUID) -> Bool {
        guard purchaseAccountToken == ownerToken, prepareCoinWallet() else { return false }
        guard journal?.revokedCoinTransactions?.contains(transactionID) != true else { return true }
        let credit = journal?.verifiedCoinCredits?[transactionID]
        return update {
            if $0.revokedCoinTransactions == nil { $0.revokedCoinTransactions = [] }
            $0.revokedCoinTransactions?.insert(transactionID)
            if let credit, credit.revokedAt == nil {
                $0.coinBalance = ($0.coinBalance ?? 0) - credit.creditedCoins
                $0.verifiedCoinCredits?[transactionID]?.revokedAt = revokedAt
                $0.walletHistory.insert(.init(detailLine: "Apple refund adjustment", tokenChange: -credit.creditedCoins), at: 0)
            }
        }
    }

    func requestKeepsake(_ keepsake: RoomKeepsake, quantity: Int = 1, roomID: String? = nil) {
        guard prepareCoinWallet(), (1...99).contains(quantity),
              let item = KokoCommunity.keepsakes.first(where: { $0.id == keepsake.id }) else { return }
        if item.wearable && ((journal?.ownedKeepsakes[item.id] ?? 0) > 0 || quantity != 1 || roomID != nil) {
            notice = "This decoration is already yours. You can wear it from your backpack without another charge."; return
        }
        if let roomID, room(roomID) == nil { notice = "This room is no longer available."; return }
        let total = item.tokenCost * quantity
        guard coinBalance >= total else { coinShortfall = .init(requiredCoins: total, purpose: item.keepsakeName); return }
        coinSpendRequest = .init(ownerID: myID, keepsakeID: item.id, quantity: quantity, roomID: roomID)
    }

    func confirmCoinSpend() {
        guard let request = coinSpendRequest else { return }
        coinSpendRequest = nil
        guard myID == request.ownerID,
              let item = KokoCommunity.keepsakes.first(where: { $0.id == request.keepsakeID }) else { return }
        let total = item.tokenCost * request.quantity
        guard coinBalance >= total else { coinShortfall = .init(requiredCoins: total, purpose: item.keepsakeName); return }
        if item.wearable && (journal?.ownedKeepsakes[item.id] ?? 0) > 0 { notice = "This decoration is already in your backpack."; return }
        let destinationRoom = request.roomID.flatMap { room($0) }
        guard request.roomID == nil || destinationRoom != nil else { notice = "This room is no longer available. No coins were spent."; return }
        let sender = myID
        if update({ journal in
            journal.coinBalance = (journal.coinBalance ?? 0) - total
            let purpose: String
            if var room = destinationRoom {
                room.roomConversation.append(.init(authorMemberID: sender, messageText: "Gifted \(item.keepsakeName) ×\(request.quantity) · local room", attachmentTile: item.artworkTile))
                journal.roomOverrides[room.id] = room
                purpose = item.keepsakeName + " ×\(request.quantity) · " + room.roomTitle
            } else {
                journal.ownedKeepsakes[item.id, default: 0] += request.quantity
                purpose = item.keepsakeName + " ×\(request.quantity) · backpack"
            }
            journal.walletHistory.insert(.init(detailLine: purpose, tokenChange: -total), at: 0)
        }) { coinShortfall = nil; notice = "\(total) coins spent on \(item.keepsakeName). Balance: \(coinBalance) coins." }
    }
}
