import Foundation

struct KokoCoinPack: Identifiable, Codable, Sendable {
    let id: String
    let coinQuantity: Int
    let referenceUSD: String
    let collectionTitle: String
    var referencePrice: Decimal { Decimal(string: referenceUSD, locale: Locale(identifier: "en_US_POSIX"))! }
    var referencePriceLabel: String { "$" + referenceUSD + " USD" }
}

@MainActor
enum KokoCoinCatalog {
    static let firstVisitGift = 600
    // StoreKit fetches one selected ID at the moment Buy is tapped. These are not downloaded prices.
    static var packs: [KokoCoinPack] { KokoCommunityCollection.shared.snapshot.arrangement.coinPacks }
    static func pack(_ productID: String) -> KokoCoinPack? { packs.first { $0.id == productID } }
}

struct VerifiedCoinCredit: Codable {
    var appleTransactionID: String
    var productIdentifier: String
    var creditedCoins: Int
    var purchasedAt: Date
    var storeEnvironment: String
    var revokedAt: Date?
}

struct CoinSpendRequest: Identifiable {
    let id = UUID()
    let ownerID: String
    let keepsakeID: String
    let quantity: Int
    let roomID: String?
}

struct CoinShortfall: Identifiable {
    let id = UUID()
    let requiredCoins: Int
    let purpose: String
}
