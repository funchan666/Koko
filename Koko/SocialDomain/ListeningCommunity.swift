import Foundation

struct CommunityMember: Identifiable, Codable, Hashable {
    var id: String
    var publicName: String
    var hometownLabel: String
    var spokenLanguage: String
    var adultAge: Int
    var genderLabel: String
    var introductionLine: String
    var portraitTile: Int
    var interests: [String]
}

struct ListeningRoom: Identifiable, Codable, Hashable {
    var id: String
    var roomTitle: String
    var conversationPrompt: String
    var hostMemberID: String
    var conversationTopic: String
    var seatLimit: Int
    var isPublicRoom: Bool
    var isVideoStage: Bool
    var artworkTile: Int
    var targetAudience: Int
    var seatAssignments: [Int: String] = [:]
    var mutedSeatNumbers: Set<Int> = []
    var roomConversation: [ConversationEntry] = []
    var hostNote: String = "Make space for every voice."
    var moderatorMemberIDs: Set<String> = []
}

struct SharedMoment: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var creatorMemberID: String
    var captionLine: String
    var topicLabel: String
    var coverTile: Int
    var bundledMovieName: String?
    var libraryAssetKey: String? = nil
}

struct ConversationEntry: Identifiable, Codable, Hashable {
    var id = UUID().uuidString
    var authorMemberID: String
    var messageText: String
    var postedAt = Date()
    var attachmentTile: Int? = nil
    var attachmentPhotoKey: String? = nil
}

struct PrivateConversation: Identifiable, Codable, Hashable {
    var id: String
    var correspondentID: String
    var entries: [ConversationEntry]
    var unreadEntries: Int = 0
    var compositionDraft: String = ""
}

struct RoomKeepsake: Identifiable, Codable, Hashable {
    let id: String
    let keepsakeName: String
    let artworkTile: Int
    let tokenCost: Int
    let wearable: Bool
}

struct TokenMovement: Identifiable, Codable, Hashable {
    var id = UUID().uuidString
    var detailLine: String
    var tokenChange: Int
    var recordedAt = Date()
}

struct CommunityNotice: Identifiable, Codable, Hashable {
    var id = UUID().uuidString
    var headline: String
    var explanation: String
    var hasBeenRead = false
    var createdAt = Date()
}

struct SafetyRecord: Identifiable, Codable, Hashable {
    var id = UUID().uuidString
    var subjectKey: String
    var selectedReason: String
    var recordedAt = Date()
}

struct PersonalJournal: Codable {
    var member: CommunityMember
    var followedMembers: Set<String> = []
    var sampleFollowers: Set<String> = []
    var blockedMembers: Set<String> = []
    var hiddenContentKeys: Set<String> = []
    var savedMomentKeys: Set<String> = []
    var likedMomentKeys: Set<String> = []
    var momentComments: [String: [ConversationEntry]] = [:]
    var createdRooms: [ListeningRoom] = []
    var roomOverrides: [String: ListeningRoom] = [:]
    var privateConversations: [PrivateConversation] = []
    var albumTiles: [Int] = []
    var albumPhotoKeys: [String]? = nil
    // Legacy demo field is decode-only in practice. It never becomes spendable purchased currency.
    var demoTokenBalance = 0
    var walletHistory: [TokenMovement] = []
    var coinBalance: Int? = nil
    var archivedDemoCoinBalance: Int? = nil
    var archivedDemoWalletHistory: [TokenMovement]? = nil
    var verifiedCoinCredits: [String: VerifiedCoinCredit]? = nil
    var revokedCoinTransactions: Set<String>? = nil
    var welcomeGiftEligible: Bool? = nil
    var welcomeGiftGrantedAt: Date? = nil
    var welcomeGiftAcknowledged: Bool? = nil
    var ownedKeepsakes: [String: Int] = [:]
    var wornKeepsakeID: String? = nil
    var checkInDayKeys: Set<String> = []
    var notices: [CommunityNotice] = [.init(headline: "Your space, your pace", explanation: "Explore Koko on this device. Rooms and conversations are local previews. Optional coin packs use Apple In-App Purchase.")]
    var safetyRecords: [SafetyRecord] = []
    var feedbackNotes: [String] = []
    var preferences: [String: Bool] = ["Show my activity": true, "Allow room invitations": true, "Message reminders": true, "Check-in reminders": false, "Room updates": true]
    var completedProfile = false
}

enum KokoCommunity {
    static let topics = ["All", "Conversation", "Music", "Creative", "After hours"]
    static let members: [CommunityMember] = [
        .init(id: "marlowe", publicName: "Marlowe", hometownLabel: "Bristol", spokenLanguage: "English", adultAge: 26, genderLabel: "Woman", introductionLine: "Records on, phone down. Tell me about your day.", portraitTile: 0, interests: ["Music", "After hours"]),
        .init(id: "eli", publicName: "Eli Santos", hometownLabel: "Lisbon", spokenLanguage: "Portuguese", adultAge: 29, genderLabel: "Man", introductionLine: "A few good stories between the songs.", portraitTile: 1, interests: ["Conversation", "Music"]),
        .init(id: "ren", publicName: "Ren", hometownLabel: "Melbourne", spokenLanguage: "English", adultAge: 24, genderLabel: "Non-binary", introductionLine: "Making things, changing my mind, starting again.", portraitTile: 2, interests: ["Creative"]),
        .init(id: "imani", publicName: "Imani Brooks", hometownLabel: "Chicago", spokenLanguage: "English", adultAge: 28, genderLabel: "Woman", introductionLine: "A listening room for the long way home.", portraitTile: 3, interests: ["After hours", "Conversation"])
    ]
    static let rooms: [ListeningRoom] = [
        .init(id: "side-a", roomTitle: "One more record", conversationPrompt: "The song you always come back to", hostMemberID: "marlowe", conversationTopic: "Music", seatLimit: 6, isPublicRoom: true, isVideoStage: false, artworkTile: 0, targetAudience: 20, seatAssignments: [0: "marlowe", 1: "eli"]),
        .init(id: "open-window", roomTitle: "The open window", conversationPrompt: "Small stories from wherever you are", hostMemberID: "eli", conversationTopic: "Conversation", seatLimit: 4, isPublicRoom: true, isVideoStage: true, artworkTile: 1, targetAudience: 12, seatAssignments: [0: "eli"]),
        .init(id: "work-in-progress", roomTitle: "Still making it", conversationPrompt: "Bring a project. Or just your curiosity.", hostMemberID: "ren", conversationTopic: "Creative", seatLimit: 8, isPublicRoom: true, isVideoStage: false, artworkTile: 0, targetAudience: 24, seatAssignments: [0: "ren", 2: "imani"]),
        .init(id: "last-light", roomTitle: "The late table", conversationPrompt: "A little company after a long day", hostMemberID: "imani", conversationTopic: "After hours", seatLimit: 6, isPublicRoom: true, isVideoStage: true, artworkTile: 1, targetAudience: 18, seatAssignments: [0: "imani", 1: "marlowe"])
    ]
    static let moments: [SharedMoment] = KokoMediaLibrary.assets.map(\.moment)
    static let keepsakes: [RoomKeepsake] = [
        .init(id: "green-rose", keepsakeName: "A little bloom", artworkTile: 8, tokenCost: 30, wearable: false),
        .init(id: "headphones", keepsakeName: "Good listening", artworkTile: 9, tokenCost: 75, wearable: false),
        .init(id: "coral-star", keepsakeName: "You made my day", artworkTile: 10, tokenCost: 160, wearable: false),
        .init(id: "mirror-ball", keepsakeName: "Room to dance", artworkTile: 11, tokenCost: 320, wearable: false),
        .init(id: "jade-crown", keepsakeName: "Room regular", artworkTile: 12, tokenCost: 1500, wearable: true),
        .init(id: "green-ribbon", keepsakeName: "Good company", artworkTile: 13, tokenCost: 480, wearable: true),
        .init(id: "pocket-radio", keepsakeName: "Pocket radio", artworkTile: 14, tokenCost: 1100, wearable: true),
        .init(id: "weekend-bag", keepsakeName: "Out of office", artworkTile: 15, tokenCost: 720, wearable: true)
    ]
}
