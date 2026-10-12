import Foundation

enum KokoCommunity {
    static let topics = ["All", "Conversation", "Music", "Creative", "After hours"]
    static let members: [CommunityMember] = [
        .init(id: "marlowe", publicName: "Marlowe", hometownLabel: "Bristol", spokenLanguage: "English", adultAge: 26, genderLabel: "Woman", introductionLine: "Records on, phone down. Tell me about your day.", portraitTile: 0, interests: ["Music", "After hours"], suppliedPortraitPhotoKey: "photo-3e29a87b4e9a5de9"),
        .init(id: "eli", publicName: "Eli Santos", hometownLabel: "Lisbon", spokenLanguage: "Portuguese", adultAge: 29, genderLabel: "Man", introductionLine: "A few good stories between the songs.", portraitTile: 1, interests: ["Conversation", "Music"], suppliedPortraitPhotoKey: "photo-f18f8ac9ab90dab5"),
        .init(id: "ren", publicName: "Ren", hometownLabel: "Melbourne", spokenLanguage: "English", adultAge: 24, genderLabel: "Non-binary", introductionLine: "Making things, changing my mind, starting again.", portraitTile: 2, interests: ["Creative"], suppliedPortraitPhotoKey: "photo-d1360451d8292f40"),
        .init(id: "imani", publicName: "Imani Brooks", hometownLabel: "Chicago", spokenLanguage: "English", adultAge: 28, genderLabel: "Woman", introductionLine: "A listening room for the long way home.", portraitTile: 3, interests: ["After hours", "Conversation"], suppliedPortraitPhotoKey: "photo-393c437ceadbdcb4"),
        .init(id: "noa", publicName: "Noa Bennett", hometownLabel: "Brighton", spokenLanguage: "English", adultAge: 27, genderLabel: "Woman", introductionLine: "Open notebooks, unexpected stories, and a little curiosity.", portraitTile: 0, interests: ["Creative", "Conversation"], suppliedPortraitPhotoKey: "photo-d4df27b33da26d96"),
        .init(id: "jules", publicName: "Jules Martin", hometownLabel: "Lyon", spokenLanguage: "French", adultAge: 25, genderLabel: "Woman", introductionLine: "One more song, then tell me what it reminds you of.", portraitTile: 0, interests: ["Music", "After hours"], suppliedPortraitPhotoKey: "photo-c09d21c84b62e0aa")
    ]
    // Only these legacy sample hosts are migrated; personal rooms and room history stay intact.
    static let previousVoiceRoomHosts = ["open-notebook": "ren", "between-songs": "marlowe"]
    static let rooms: [HostedConversationRoom] = [
        .init(id: "side-a", roomTitle: "One more record", conversationPrompt: "The song you always come back to", hostMemberID: "marlowe", conversationTopic: "Music", seatLimit: 6, isPublicRoom: true, isVideoStage: false, artworkTile: 0, audienceGoal: 20, seatAssignments: [0: "marlowe", 1: "eli", 2: "ren"]),
        .init(id: "open-window", roomTitle: "The open window", conversationPrompt: "Small stories from wherever you are", hostMemberID: "eli", conversationTopic: "Conversation", seatLimit: 4, isPublicRoom: true, isVideoStage: true, artworkTile: 1, audienceGoal: 12, seatAssignments: [0: "eli", 1: "marlowe", 2: "ren"]),
        .init(id: "work-in-progress", roomTitle: "Still making it", conversationPrompt: "Bring a project. Or just your curiosity.", hostMemberID: "ren", conversationTopic: "Creative", seatLimit: 8, isPublicRoom: true, isVideoStage: false, artworkTile: 0, audienceGoal: 24, seatAssignments: [0: "ren", 1: "imani", 2: "marlowe"]),
        .init(id: "last-light", roomTitle: "The late table", conversationPrompt: "A little company after a long day", hostMemberID: "imani", conversationTopic: "After hours", seatLimit: 6, isPublicRoom: true, isVideoStage: true, artworkTile: 1, audienceGoal: 18, seatAssignments: [0: "imani", 1: "marlowe", 2: "eli"]),
        .init(id: "morning-window", roomTitle: "Morning window", conversationPrompt: "Open the day with a small hello", hostMemberID: "marlowe", conversationTopic: "Conversation", seatLimit: 6, isPublicRoom: true, isVideoStage: true, artworkTile: 1, audienceGoal: 16, seatAssignments: [0: "marlowe", 1: "eli", 2: "imani"]),
        .init(id: "studio-open", roomTitle: "Studio open", conversationPrompt: "Show the sketch, share the process", hostMemberID: "ren", conversationTopic: "Creative", seatLimit: 8, isPublicRoom: true, isVideoStage: true, artworkTile: 0, audienceGoal: 22, seatAssignments: [0: "ren", 1: "imani", 2: "marlowe"]),
        .init(id: "night-signal", roomTitle: "Night signal", conversationPrompt: "A softer place to land after work", hostMemberID: "imani", conversationTopic: "After hours", seatLimit: 6, isPublicRoom: true, isVideoStage: true, artworkTile: 1, audienceGoal: 18, seatAssignments: [0: "imani", 1: "ren"]),
        .init(id: "tiny-dancefloor", roomTitle: "Tiny dancefloor", conversationPrompt: "Bring one song and a little joy", hostMemberID: "eli", conversationTopic: "Music", seatLimit: 6, isPublicRoom: true, isVideoStage: true, artworkTile: 0, audienceGoal: 20, seatAssignments: [0: "eli", 1: "marlowe", 2: "ren"]),
        .init(id: "table-talk", roomTitle: "Around the table", conversationPrompt: "Pull up a chair and share something from your day", hostMemberID: "ren", conversationTopic: "Conversation", seatLimit: 6, isPublicRoom: true, isVideoStage: true, artworkTile: 1, audienceGoal: 20, seatAssignments: [0: "ren"]),
        .init(id: "trail-stories", roomTitle: "The long way home", conversationPrompt: "A little fresh air and a story worth sharing", hostMemberID: "imani", conversationTopic: "Conversation", seatLimit: 6, isPublicRoom: true, isVideoStage: true, artworkTile: 1, audienceGoal: 20, seatAssignments: [0: "imani"]),
        .init(id: "quiet-arcade", roomTitle: "Quiet arcade", conversationPrompt: "Talk games, memories and tiny wins", hostMemberID: "eli", conversationTopic: "Conversation", seatLimit: 6, isPublicRoom: true, isVideoStage: false, artworkTile: 0, audienceGoal: 16, seatAssignments: [0: "eli", 1: "ren"]),
        .init(id: "open-notebook", roomTitle: "Open notebook", conversationPrompt: "Read a page or bring a question", hostMemberID: "noa", conversationTopic: "Creative", seatLimit: 8, isPublicRoom: true, isVideoStage: false, artworkTile: 0, audienceGoal: 20, seatAssignments: [0: "noa", 1: "marlowe", 2: "eli"]),
        .init(id: "between-songs", roomTitle: "Between songs", conversationPrompt: "The stories that live between the tracks", hostMemberID: "jules", conversationTopic: "Music", seatLimit: 6, isPublicRoom: true, isVideoStage: false, artworkTile: 0, audienceGoal: 18, seatAssignments: [0: "jules", 1: "imani"]),
        .init(id: "slow-morning", roomTitle: "Slow morning", conversationPrompt: "A gentle check-in before the day begins", hostMemberID: "imani", conversationTopic: "After hours", seatLimit: 6, isPublicRoom: true, isVideoStage: false, artworkTile: 0, audienceGoal: 14, seatAssignments: [0: "imani", 1: "ren"])
    ]
    static let moments: [SharedMoment] = KokoMediaLibrary.assets.map(\.moment)
    static let keepsakes: [RoomKeepsake] = [
        .init(id: "green-rose", keepsakeName: "A little bloom", artworkTile: 8, coinPrice: 30, wearable: false),
        .init(id: "headphones", keepsakeName: "Good listening", artworkTile: 9, coinPrice: 75, wearable: false),
        .init(id: "coral-star", keepsakeName: "You made my day", artworkTile: 10, coinPrice: 160, wearable: false),
        .init(id: "mirror-ball", keepsakeName: "Room to dance", artworkTile: 11, coinPrice: 320, wearable: false),
        .init(id: "jade-crown", keepsakeName: "Room regular", artworkTile: 12, coinPrice: 1500, wearable: true),
        .init(id: "green-ribbon", keepsakeName: "Good company", artworkTile: 13, coinPrice: 480, wearable: true),
        .init(id: "pocket-radio", keepsakeName: "Pocket radio", artworkTile: 14, coinPrice: 1100, wearable: true),
        .init(id: "weekend-bag", keepsakeName: "Out of office", artworkTile: 15, coinPrice: 720, wearable: true)
    ]
}
