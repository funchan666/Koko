import Foundation
import StoreKit
import Combine

/// No StoreKit configuration file or simulated-success fallback is used by this app.
@MainActor
final class KokoAppleCoinPurchases: ObservableObject {
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
        guard purchasingProductID == nil, !recoveringOrders,
              let community, let ownerToken = community.purchaseAccountToken,
              community.journal?.completedProfile == true, community.prepareCoinWallet() else { return }
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
        guard recoveryTask == nil, purchasingProductID == nil,
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
        guard let pack = KokoCoinCatalog.pack(transaction.productID), transaction.productType == .consumable else { return }
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
