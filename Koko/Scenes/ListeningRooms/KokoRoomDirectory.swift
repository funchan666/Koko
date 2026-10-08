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
        KokoPage(title: "Pull up a chair", subtitle: "GOOD CONVERSATIONS HAVE ROOM FOR YOU") {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("A room for\nevery mood.").font(.custom("AvenirNext-Bold", size: 30))
                    Text("Listen first. Speak when you're ready.").font(.custom("AvenirNext-Regular", size: 13)).foregroundStyle(KokoInk.secondary)
                }
                Artwork(sheet: .scenes, tile: 0).frame(width: 128, height: 138)
            }
            HStack { KokoAction(title: "Make a room", icon: 7) { navigation.open(.createRoom(false)) }; KokoIconAction(icon: 15, label: "Room ranking") { navigation.open(.ranking) } }
            KokoField(label: "Find a conversation", value: $search)
            KokoChoiceRail(choices: ["All", "Following"] + Array(KokoCommunity.topics.dropFirst()), selection: $topic)
            HStack { Text("The doors are open").font(.custom("AvenirNext-Bold", size: 21)); Spacer(); Text("\(filtered.count) rooms").font(.custom("AvenirNext-Medium", size: 12)) }
            ForEach(filtered) { room in KokoRoomCard(room: room) }
            if filtered.isEmpty { KokoEmpty(title: "A quiet corner", detail: "Try a different category, or start a room of your own.") }
            LocalPreviewNote()
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
