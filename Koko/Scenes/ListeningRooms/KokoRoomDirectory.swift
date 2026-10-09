import SwiftUI

struct KokoRoomDirectory: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @State private var topic = "All"
    @State private var search = ""
    var filtered: [ListeningRoom] {
        community.rooms.filter { (topic == "All" || (topic == "Following" ? community.following.contains($0.hostMemberID) : $0.conversationTopic == topic)) && (search.isEmpty || $0.roomTitle.localizedCaseInsensitiveContains(search)) }
    }
    var body: some View {
        KokoPage(title: "Rooms", subtitle: "Listen in. Find a conversation.") {
            KokoSearchField(prompt: "Search rooms", query: $search)
            HStack(spacing: 10) {
                KokoAction(title: "Create a voice room", icon: 7) { navigation.open(.createRoom(false)) }
                KokoIconAction(icon: 15, label: "Room ranking") { navigation.open(.ranking) }
            }
            KokoChoiceRail(choices: ["All", "Following"] + Array(KokoCommunity.topics.dropFirst()), selection: $topic)
            KokoSectionTitle(title: "Find your room", detail: "\(filtered.count) rooms")
            ForEach(filtered) { room in KokoRoomCard(room: room) }
            if filtered.isEmpty { KokoEmpty(title: "A quiet corner", detail: "Choose another category, or start a room of your own.", art: 1) }
            LocalPreviewNote(text: "LOCAL ROOM PREVIEWS · NO AUDIO IS BROADCAST")
        }
    }
}

struct KokoRoomComposer: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    let videoStage: Bool
    @State private var roomTitle = ""
    @State private var conversationPrompt = ""
    @State private var targetAudience = "20"
    @State private var topic = "Conversation"
    @State private var seats = "6"
    @State private var publicRoom = true
    @State private var cover = 0
    var body: some View {
        KokoPage(title: videoStage ? "Your little stage" : "Set the table", subtitle: "Give people a reason to stay.", back: navigation.back) {
            Artwork(sheet: .scenes, tile: cover).frame(height: 210)
            HStack { KokoAction(title: "Daylight", emphasis: cover == 0) { cover = 0 }; KokoAction(title: "After dark", emphasis: cover == 1) { cover = 1 } }
            KokoField(label: "Room name · up to 50 characters", value: $roomTitle)
            KokoField(label: "What are we talking about?", value: $conversationPrompt, multiline: true)
            KokoField(label: "Audience goal · 1–999", value: $targetAudience, keyboard: .numberPad)
            KokoChoiceRail(choices: Array(KokoCommunity.topics.dropFirst()), selection: $topic)
            Text("Seats at your table").font(.custom("AvenirNext-DemiBold", size: 16))
            KokoChoiceRail(choices: ["3", "4", "6", "8", "9", "12"], selection: $seats)
            KokoToggleRow(title: "Public room", enabled: $publicRoom)
            LocalPreviewNote(text: "CREATES A ROOM ON THIS DEVICE. NO AUDIO OR VIDEO IS BROADCAST.")
            KokoAction(title: "Open my room", icon: 1) {
                let title = roomTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty, title.count <= 50, conversationPrompt.count <= 240, let audience = Int(targetAudience), (1...999).contains(audience) else { community.notice = "Add a room name up to 50 characters, a description up to 240 characters, and an audience goal from 1 to 999."; return }
                let room = ListeningRoom(id: UUID().uuidString, roomTitle: title, conversationPrompt: conversationPrompt, hostMemberID: community.myID, conversationTopic: topic, seatLimit: Int(seats) ?? 6, isPublicRoom: publicRoom, isVideoStage: videoStage, artworkTile: cover, targetAudience: audience, seatAssignments: [0: community.myID], mutedSeatNumbers: [0])
                if community.saveRoom(room, creating: true) { navigation.back(); navigation.open(.room(room.id)) }
            }
        }
    }
}
