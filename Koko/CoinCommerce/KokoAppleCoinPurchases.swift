import Foundation
import StoreKit
import Combine

/// No StoreKit configuration file or simulated-success fallback is used by this app.
@MainActor
final class KokoAppleCoinPurchases: ObservableObject {
    @Published private(set) var gatewayPaymentCaption: String?
    private let receiptRefresh = KokoPurchaseReceiptRefresh()
    private let roomOrders = KokoRoomOrderJournal()
    private var gatewayPurchaseTask: Task<Void, Never>?
    private var gatewayRecoveryTask: Task<Void, Never>?
    private var settlingRoomTransactions = Set<String>()
    private var settlementWaiters: [String: [CheckedContinuation<Void, Never>]] = [:]
    private var gatewayMaskGeneration = UUID()

    @Published private(set) var purchasingProductID: String?
    @Published private(set) var phaseDescription = ""
    @Published private(set) var localizedPrices: [String: String] = [:]
    @Published private(set) var recoveringOrders = false
    @Published var purchaseMessage: String?
    private weak var community: CommunityJournalStore?
    private var updatesTask: Task<Void, Never>?
    private var recoveryTask: Task<Void, Never>?

    func startObserving(community: CommunityJournalStore) {
        self.community = community
        recoverGatewayOrders()
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await result in StoreKit.Transaction.updates {
                guard !Task.isCancelled else { break }
                await self?.deliver(result)
            }
        }
    }

    /// Called only by a Buy button. The rest of the app must not call Product.products(for:).
    func purchase(_ pack: KokoCoinPack) async {
        guard purchasingProductID == nil, gatewayPurchaseTask == nil, !recoveringOrders,
              let community, let ownerToken = community.purchaseAccountToken,
              community.hasCompletedAccountEntry, community.prepareCoinWallet() else { return }
        guard !roomOrders.requiresOrderReview(product: pack.id, token: ownerToken) else {
            purchaseMessage = "An earlier purchase is awaiting confirmation. Please do not purchase it again."; return
        }
        guard AppStore.canMakePayments else {
            purchaseMessage = "Apple purchases are not allowed on this device. Check your Screen Time purchase restrictions."; return
        }
        purchasingProductID = pack.id
        community.purchaseInProgress = true
        phaseDescription = "Getting this pack from Apple…"
        defer {
            purchasingProductID = nil
            community.purchaseInProgress = false
            phaseDescription = ""
        }
        do {
            let products = try await Product.products(for: [pack.id])
            guard community.purchaseAccountToken == ownerToken else {
                purchaseMessage = "Your Koko account changed. No new purchase was started."; return
            }
            guard let product = products.first(where: { $0.id == pack.id }), product.type == .consumable else {
                purchaseMessage = "Apple has not made this coin pack available for this app and storefront. No purchase was started. Please try again later."; return
            }
            // USD anchors are fixed by the operator; other storefronts use Apple's localized price.
            guard product.priceFormatStyle.currencyCode != "USD" || product.price == pack.referencePrice else {
                purchaseMessage = "Apple's price for this pack does not match its configured US price. No purchase was started."; return
            }
            localizedPrices[pack.id] = product.displayPrice
            phaseDescription = "Confirm your purchase with Apple"
            let result = try await product.purchase(options: [.appAccountToken(ownerToken), .quantity(1)])
            switch result {
            case .success(let verification):
                phaseDescription = "Verifying and adding your coins…"
                await deliver(verification)
            case .pending:
                purchaseMessage = "This purchase is waiting for Apple's approval. Coins will be added after Apple confirms it; you do not need to buy it again."
            case .userCancelled:
                purchaseMessage = "Purchase cancelled. Your coin balance has not changed."
            @unknown default:
                purchaseMessage = "Apple has not confirmed this purchase yet. Use Check unfinished purchases before trying again."
            }
        } catch {
            purchaseMessage = "The Apple purchase could not be completed. Check your connection and try again. If Apple charged you, use Check unfinished purchases; do not buy again."
        }
    }

    func recoverUnfinishedPurchases(showResult: Bool = false) {
        guard recoveryTask == nil, purchasingProductID == nil, gatewayPurchaseTask == nil,
              let ownerToken = community?.purchaseAccountToken else { return }
        recoveringOrders = true
        recoveryTask = Task { [weak self] in
            guard let self else { return }
            defer {
                self.recoveringOrders = false; self.recoveryTask = nil
                if let currentOwner = self.community?.purchaseAccountToken, currentOwner != ownerToken {
                    self.recoverUnfinishedPurchases()
                }
            }
            var matched = false
            for await verification in StoreKit.Transaction.unfinished {
                guard !Task.isCancelled, self.community?.purchaseAccountToken == ownerToken else { return }
                if case .verified(let transaction) = verification,
                   transaction.appAccountToken == ownerToken,
                   KokoCoinCatalog.pack(transaction.productID) != nil {
                    matched = true
                    await self.deliver(verification)
                } else if case .unverified(let transaction, _) = verification,
                          KokoCoinCatalog.pack(transaction.productID) != nil {
                    matched = true
                    await self.deliver(verification)
                }
            }
            // Replay only refunds for known local credits. Never re-grant finished consumables from history.
            for await verification in StoreKit.Transaction.all {
                guard !Task.isCancelled, self.community?.purchaseAccountToken == ownerToken else { return }
                if case .verified(let transaction) = verification,
                   transaction.revocationDate != nil,
                   transaction.appAccountToken == ownerToken,
                   self.community?.journal?.verifiedCoinCredits?[String(transaction.id)] != nil {
                    await self.deliver(verification)
                }
            }
            if showResult && !matched {
                self.purchaseMessage = "No unfinished coin purchases were found for this Koko account. Completed consumable packs are not credited again."
            }
        }
    }

    private func deliver(_ result: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let transaction) = result else {
            purchaseMessage = "Apple's transaction could not be verified. No coins were added. The order remains unfinished for a later retry."; return
        }
        if roomOrders.boundOrder(transaction: String(transaction.id), token: transaction.appAccountToken) != nil {
            await settleRoomTransaction(transaction); return
        }
        if roomOrders.requiresOrderReview(product: transaction.productID, token: transaction.appAccountToken) {
            roomOrders.quarantine(transaction: String(transaction.id), product: transaction.productID, token: transaction.appAccountToken)
            return
        }
        guard let pack = KokoCoinCatalog.pack(transaction.productID), transaction.productType == .consumable else {
            roomOrders.quarantine(transaction: String(transaction.id), product: transaction.productID, token: transaction.appAccountToken); return
        }
        guard let community, let ownerToken = transaction.appAccountToken,
              community.purchaseAccountToken == ownerToken else {
            // A pending order must never follow whichever account happens to be signed in now.
            purchaseMessage = "An Apple coin order belongs to another Koko account. Sign in to the account used for that purchase to receive it."; return
        }
        let transactionID = String(transaction.id)
        if let revoked = transaction.revocationDate {
            let previousCredit = community.journal?.verifiedCoinCredits?[transactionID]
            let needsAdjustment = previousCredit != nil && previousCredit?.revokedAt == nil
            guard community.recordPurchaseRevocation(transactionID: transactionID, revokedAt: revoked, ownerToken: ownerToken) else { return }
            await transaction.finish()
            if needsAdjustment && community.purchaseAccountToken == ownerToken { purchaseMessage = "Apple refunded a coin purchase. Your balance and history have been updated." }
            return
        }
        if community.journal?.verifiedCoinCredits?[transactionID] != nil || community.journal?.revokedCoinTransactions?.contains(transactionID) == true {
            await transaction.finish()
            return
        }
        let quantity = transaction.purchasedQuantity
        guard quantity > 0, quantity <= Int.max / pack.coinQuantity else {
            purchaseMessage = "This order quantity could not be processed. The order has been kept unfinished."; return
        }
        let credit = VerifiedCoinCredit(appleTransactionID: transactionID, productIdentifier: transaction.productID,
                                       creditedCoins: pack.coinQuantity * quantity, purchasedAt: transaction.purchaseDate,
                                       storeEnvironment: transaction.environment.rawValue, revokedAt: nil)
        guard community.recordVerifiedPurchase(credit, ownerToken: ownerToken) else {
            purchaseMessage = "Apple confirmed your order, but its coins could not be saved on this device. Free some storage and check unfinished purchases. Do not buy this pack again."; return
        }
        // Finish only after BOTH balance and transaction identity have been written atomically.
        await transaction.finish()
        if community.purchaseAccountToken == ownerToken {
            purchaseMessage = "\(credit.creditedCoins) coins added. Your balance is now \(community.coinBalance) coins."
        }
    }
}

extension KokoAppleCoinPurchases {
    func detachGatewayMask() { gatewayMaskGeneration = UUID(); gatewayPaymentCaption = nil }

    func purchaseGatewayOrder(order reference: String, productID: String, eventID: String) {
        guard gatewayPurchaseTask == nil, purchasingProductID == nil, !recoveringOrders,
              let community, let accountToken = community.purchaseAccountToken,
              roomOrders.available, AppStore.canMakePayments else {
            purchaseMessage = roomOrders.failure ?? "Another purchase is being processed. Please try again shortly."; return
        }
        if roomOrders.orders.contains(where: { $0.eventID == eventID }) {
            recoverGatewayOrders(); return
        }
        if roomOrders.orders.contains(where: { $0.orderReference == reference && $0.state != .cancelled && $0.state != .prepared }) {
            recoverGatewayOrders(); return
        }
        if roomOrders.requiresOrderReview(product: productID, token: accountToken) {
            purchaseMessage = "An earlier purchase is awaiting confirmation. Please do not purchase it again."
            recoverGatewayOrders(); return
        }
        let mask = UUID(); gatewayMaskGeneration = mask
        gatewayPaymentCaption = "Preparing your purchase…"
        community.purchaseInProgress = true
        gatewayPurchaseTask = Task {
            defer {
                gatewayPurchaseTask = nil
                if gatewayMaskGeneration == mask { gatewayPaymentCaption = nil }
                community.purchaseInProgress = false
            }
            do {
                var order = KokoRoomOrder(id: UUID(), eventID: eventID, orderReference: reference, productID: productID,
                    ownerID: community.myID, accountToken: accountToken, installationID: try KokoGatewayClient.shared.installationID(),
                    edition: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
                    origin: IntegrationContract.baseURLString ?? "", settlementPath: IntegrationContract.settlementPath,
                    editionField: "koko_edition", installationField: "listener_installation", transactionField: "apple_keepsake_transaction",
                    receiptField: "keepsake_receipt", orderField: "room_order_reference", createdAt: Date(), state: .prepared)
                try roomOrders.save(order)
                let products = try await Product.products(for: [productID])
                guard let product = products.first(where: { $0.id == productID && $0.type == .consumable }),
                      community.myID == order.ownerID, community.purchaseAccountToken == accountToken,
                      gatewayMaskGeneration == mask else { throw KokoGatewayClient.Failure.rejected }
                order.state = .awaitingApple; try roomOrders.save(order)
                if gatewayMaskGeneration == mask { gatewayPaymentCaption = "Waiting for Apple…" }
                switch try await product.purchase(options: [.appAccountToken(accountToken), .quantity(1)]) {
                case .success(let result):
                    if gatewayMaskGeneration == mask { gatewayPaymentCaption = "Confirming your purchase…" }
                    if case .verified(let transaction) = result {
                        guard transaction.productID == order.productID, transaction.appAccountToken == accountToken,
                              roomOrders.boundOrder(transaction: String(transaction.id), token: transaction.appAccountToken).map({ $0.id == order.id }) ?? true else {
                            roomOrders.quarantine(transaction: String(transaction.id), product: transaction.productID, token: transaction.appAccountToken)
                            throw KokoGatewayClient.Failure.rejected
                        }
                        if let index = roomOrders.orders.firstIndex(where: { $0.id == order.id }) {
                            var paid = roomOrders.orders[index]
                            if paid.transactionID == nil {
                                paid.transactionID = String(transaction.id); paid.state = .purchased; try roomOrders.save(paid)
                            }
                        }
                        let receiptExists = Bundle.main.appStoreReceiptURL.flatMap { try? Data(contentsOf: $0) }.map { !$0.isEmpty } ?? false
                        if !receiptExists, community.myID == order.ownerID, gatewayMaskGeneration == mask {
                            await receiptRefresh.refreshForForegroundPurchase()
                        }
                        await settleRoomTransaction(transaction)
                        if roomOrders.orders.first(where: { $0.id == order.id })?.state != .finished {
                            purchaseMessage = "Apple recorded your purchase. Confirmation is pending and will retry automatically. Please do not purchase it again."
                        }
                    } else { purchaseMessage = "The Apple transaction could not be verified. It remains unfinished." }
                case .pending: purchaseMessage = "Apple is waiting for approval. Your order will be recovered when approved."
                case .userCancelled: order.state = .cancelled; try roomOrders.save(order)
                @unknown default: break
                }
            } catch { purchaseMessage = "The purchase could not be completed. Any paid order has been kept for recovery." }
        }
    }

    func recoverGatewayOrders() {
        guard gatewayRecoveryTask == nil, roomOrders.available else { return }
        gatewayRecoveryTask = Task {
            defer { gatewayRecoveryTask = nil }
            for await result in StoreKit.Transaction.unfinished {
                guard !Task.isCancelled else { return }
                if case .verified(let transaction) = result {
                    if roomOrders.boundOrder(transaction: String(transaction.id), token: transaction.appAccountToken) != nil {
                        await settleRoomTransaction(transaction)
                    } else if roomOrders.requiresOrderReview(product: transaction.productID, token: transaction.appAccountToken) || KokoCoinCatalog.pack(transaction.productID) == nil {
                        roomOrders.quarantine(transaction: String(transaction.id), product: transaction.productID, token: transaction.appAccountToken)
                    }
                }
            }
            for order in roomOrders.orders where order.state == .purchased {
                guard let transactionID = order.transactionID, !settlingRoomTransactions.contains(transactionID) else { continue }
                settlingRoomTransactions.insert(transactionID)
                await confirmRoomOrder(order, transactionID: transactionID)
                finishSettlementAttempt(transactionID)
            }
        }
    }

    private func finishSettlementAttempt(_ id: String) {
        settlingRoomTransactions.remove(id)
        let waiters = settlementWaiters.removeValue(forKey: id) ?? []
        for waiter in waiters { waiter.resume() }
    }

    private func settleRoomTransaction(_ transaction: StoreKit.Transaction) async {
        let transactionID = String(transaction.id)
        guard let stored = roomOrders.boundOrder(transaction: transactionID, token: transaction.appAccountToken),
              stored.productID == transaction.productID else {
            roomOrders.quarantine(transaction: transactionID, product: transaction.productID, token: transaction.appAccountToken); return
        }
        if settlingRoomTransactions.contains(transactionID) {
            await withCheckedContinuation { settlementWaiters[transactionID, default: []].append($0) }
            guard roomOrders.orders.first(where: { $0.id == stored.id })?.state == .confirmed else { return }
            await settleRoomTransaction(transaction); return
        }
        settlingRoomTransactions.insert(transactionID)
        defer { finishSettlementAttempt(transactionID) }
        var order = stored
        do {
            if order.transactionID == nil { order.transactionID = transactionID; order.state = .purchased; try roomOrders.save(order) }
            guard order.transactionID == transactionID else { return }
            if order.state != .confirmed && order.state != .finished { await confirmRoomOrder(order, transactionID: transactionID) }
            guard var confirmed = roomOrders.orders.first(where: { $0.id == order.id }), confirmed.state == .confirmed || confirmed.state == .finished else { return }
            await transaction.finish()
            confirmed.state = .finished; try roomOrders.save(confirmed)
        } catch { purchaseMessage = "This purchase is saved by Apple and remains unfinished until it can be recorded safely." }
    }

    private func confirmRoomOrder(_ order: KokoRoomOrder, transactionID: String) async {
        guard order.state == .purchased, let receiptURL = Bundle.main.appStoreReceiptURL,
              let receipt = try? Data(contentsOf: receiptURL), !receipt.isEmpty else { return }
        for delay in [0, 2, 5] {
            do {
                if delay > 0 { try await Task.sleep(for: .seconds(delay)) }
                let response = try await KokoGatewayClient.shared.settlement(origin: order.origin, path: order.settlementPath,
                    fields: [order.editionField: order.edition, order.installationField: order.installationID,
                             order.transactionField: transactionID, order.receiptField: receipt.base64EncodedString(), order.orderField: order.orderReference])
                guard KokoGatewayClient.integer(response["code"]) == 0 else { throw KokoGatewayClient.Failure.rejected }
                var confirmed = order; confirmed.state = .confirmed; try roomOrders.save(confirmed); return
            } catch { if Task.isCancelled { return } }
        }
    }
}
