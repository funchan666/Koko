import Foundation

struct KokoCoinPack: Identifiable, Sendable {
    let id: String
    let coinQuantity: Int
    let referenceUSD: String
    let collectionTitle: String
    var referencePrice: Decimal { Decimal(string: referenceUSD, locale: Locale(identifier: "en_US_POSIX"))! }
    var referencePriceLabel: String { "$" + referenceUSD + " USD" }
}

enum KokoCoinCatalog {
    static let firstVisitGift = 600
    // StoreKit fetches one selected ID at the moment Buy is tapped. These are not downloaded prices.
    static let packs: [KokoCoinPack] = [
        .init(id: "hrsrzorpkreajmwb", coinQuantity: 360, referenceUSD: "0.99", collectionTitle: "A little hello"),
        .init(id: "nfqsfmisuvrnetzu", coinQuantity: 780, referenceUSD: "1.99", collectionTitle: "Good company"),
        .init(id: "pmwqzntlcxvfrsda", coinQuantity: 1240, referenceUSD: "2.99", collectionTitle: "Side A"),
        .init(id: "rkkuocvmcmaqhxlq", coinQuantity: 2280, referenceUSD: "4.99", collectionTitle: "On repeat"),
        .init(id: "rvthzqpamnueclfd", coinQuantity: 4920, referenceUSD: "9.99", collectionTitle: "The listening room"),
        .init(id: "ztyjvowtyrkjtspk", coinQuantity: 10600, referenceUSD: "19.99", collectionTitle: "Long weekend"),
        .init(id: "kdhvxqjpnrtwbsme", coinQuantity: 16800, referenceUSD: "29.99", collectionTitle: "Double album"),
        .init(id: "tsvizuhgbkfzzhos", coinQuantity: 29600, referenceUSD: "49.99", collectionTitle: "The record shelf"),
        .init(id: "aiapsuakjxhtmttt", coinQuantity: 64800, referenceUSD: "99.99", collectionTitle: "Full collection")
    ]
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
