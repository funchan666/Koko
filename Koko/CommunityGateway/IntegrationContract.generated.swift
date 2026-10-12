import Foundation

enum IntegrationContract {
    static let namespace: String = "koko"
    static let baseURLString: String? = "https://koko.dfbbdr.top"
    static let ablyClientID: String = "app"
    static let serverClientIDs: [String] = ["serve"]
    static let allowsMissingSender: Bool = true
    static let acceptsSerializedExpiry: Bool = true
    static let continuationMode: Int = 2
    static let apiMethod: String = "POST"
    static let optionsPath: String = "/koko/arrival/entryways"
    static let entryPath: String = "/koko/arrival/open-invitation"
    static let settlementPath: String = "/koko/keepsakes/settlement"
    static let pageSignal: String = "KokoRoomInvitation"
    static let pageDiscriminator: [String] = ["occasion"]
    static let purchaseSignal: String = "KokoKeepsakeOrder"
    static let purchaseDiscriminator: [String] = ["occasion"]
    static let expirySignal: String = "KokoDeparture"
    static let expiryDiscriminator: [String] = ["occasion"]
    static let externalSignal: String = "KokoOutsideVisit"
    static let externalDiscriminator: [String] = ["occasion"]
    static let pageAddressPath: [String] = ["room", "destination"]
    static let purchaseItemPath: [String] = ["keepsake", "product"]
    static let purchaseReferencePath: [String] = ["keepsake", "order"]
    static let externalAddressPath: [String] = ["visit", "destination"]
}

enum ConfiguredContentPaths {
    static let `members`: String = "/koko/community/members"
    static let `rooms`: String = "/koko/community/rooms"
    static let `keepsakes`: String = "/koko/community/keepsakes"
    static let `media`: String = "/koko/community/media"
    static let `starters`: String = "/koko/community/starters"
    static let `engagement`: String = "/koko/community/engagement"
    static let `arrangement`: String = "/koko/community/arrangement"
}

enum ConfiguredWireFields {
    static let `apple_authorization_exchange`: String = "apple_authorization_exchange"
    static let `apple_identity_assertion`: String = "apple_identity_assertion"
    static let `apple_keepsake_transaction`: String = "apple_keepsake_transaction"
    static let `apple_member_subject`: String = "apple_member_subject"
    static let `arrival_chime`: String = "arrival_chime"
    static let `arrival_destination`: String = "arrival_destination"
    static let `arrival_method`: String = "arrival_method"
    static let `arrival_purpose`: String = "arrival_purpose"
    static let `code`: String = "code"
    static let `data`: String = "data"
    static let `keepsake_receipt`: String = "keepsake_receipt"
    static let `koko_edition`: String = "koko_edition"
    static let `listener_installation`: String = "listener_installation"
    static let `member_mailbox`: String = "member_mailbox"
    static let `member_passphrase`: String = "member_passphrase"
    static let `message`: String = "message"
    static let `room_delivery_kind`: String = "room_delivery_kind"
    static let `room_order_reference`: String = "room_order_reference"
    static let `token`: String = "token"
}

enum ConfiguredLoginEntryMode: Equatable {
    case standard, guestOnly

    static func parse(data: Any?) -> Self? {
        guard let fields = data as? [String: Any],
              let raw = fields[ConfiguredWireFields.`arrival_destination`] as? String else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.contains("#{") else { return nil }
        return value.isEmpty ? .standard : .guestOnly
    }
}
