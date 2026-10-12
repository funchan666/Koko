import Foundation

struct MemberAccountArchive: Codable {
    var member: CommunityMember
    var accountCredentialKind: String? = nil
    var appleSubjectIdentifier: String? = nil
    var policyConsent: KokoPolicyConsent? = nil
    var followedMembers: Set<String> = []
    var sampleFollowers: Set<String> = [] // Legacy only; never authorizes chat.
    var confirmedFollowerIDs: Set<String>? = nil
    var removedSimulatedRelationships: Bool? = nil
    var pendingMoments: [PendingCommunityMoment]? = nil
    var conversationPlans: [ConversationRunSheet]? = nil
    var conversationEditionIDs: Set<String>? = nil
    // Optional so existing account journals decode without a migration/reset.
    var sampleFollowerArrivals: [SampleFollowerArrival]? = nil
    var blockedMembers: Set<String> = []
    var hiddenContentKeys: Set<String> = []
    var savedMomentKeys: Set<String> = []
    var savedConversationStarterIDs: Set<String>? = nil
    var likedMomentKeys: Set<String> = []
    var momentComments: [String: [ConversationEntry]] = [:]
    var createdRooms: [HostedConversationRoom] = []
    var roomOverrides: [String: HostedConversationRoom] = [:]
    var privateConversations: [PrivateConversation] = []
    var albumTiles: [Int] = []
    var albumPhotoKeys: [String]? = nil
    // Legacy demo field is decode-only in practice. It never becomes spendable purchased currency.
    var demoTokenBalance = 0
    var walletHistory: [CoinLedgerEntry] = []
    var coinBalance: Int? = nil
    var archivedDemoCoinBalance: Int? = nil
    var archivedDemoWalletHistory: [CoinLedgerEntry]? = nil
    var verifiedCoinCredits: [String: VerifiedCoinCredit]? = nil
    var revokedCoinTransactions: Set<String>? = nil
    var welcomeGiftEligible: Bool? = nil
    var welcomeGiftGrantedAt: Date? = nil
    // Legacy popup acknowledgement is retained to migrate old gifts into read/unread inbox messages.
    var welcomeGiftAcknowledged: Bool? = nil
    var ownedKeepsakes: [String: Int] = [:]
    var wornKeepsakeID: String? = nil
    var checkInDayKeys: Set<String> = []
    var notices: [CommunityNotice] = [.init(headline: "Your space, your pace", explanation: "Explore Koko on this device. Rooms and conversations are ready to explore. Optional coin packs use Apple In-App Purchase.")]
    var safetyRecords: [ContentReportReceipt] = []
    var feedbackNotes: [String] = []
    var preferences: [String: Bool] = ["Show my activity": true, "Allow room invitations": true, "Message reminders": true, "Check-in reminders": false, "Room updates": true]
    var completedProfile = false
    // Email sign-in may enter home without claiming that personal details were supplied.
    var enteredHomeViaEmail: Bool? = nil
}
