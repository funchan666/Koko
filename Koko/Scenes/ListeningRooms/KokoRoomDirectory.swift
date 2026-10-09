import SwiftUI

struct KokoRoomDirectory: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @State private var topic = "All"
    @State private var audience = "Voice rooms"
    @State private var search = ""
    @State private var choosingTopic = false
    private var filtered: [ListeningRoom] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return community.rooms.filter { room in
            !room.isVideoStage
                && (topic == "All" || room.conversationTopic == topic)
                && (audience == "Voice rooms" || community.following.contains(room.hostMemberID))
                && (query.isEmpty || (room.roomTitle + " " + room.conversationTopic + " "
                    + (community.member(room.hostMemberID)?.publicName ?? "")).localizedCaseInsensitiveContains(query))
        }
    }
    var body: some View {
        ZStack {
            KokoPage {
                KokoSocialHero(
                    eyebrow: "Room for a hello",
                    title: "Pull up a chair",
                    detail: "Small voice rooms for real conversations and easy first hellos.",
                    artwork: 0
                )
                HStack(spacing: 10) {
                    KokoSearchField(prompt: "Search voice rooms", query: $search)
                    KokoIconAction(icon: 7, label: "Create a voice room") { navigation.open(.createRoom(false)) }
                }
                HStack(spacing: 10) {
                    KokoChoiceRail(choices: ["Voice rooms", "Following"], selection: $audience)
                    KokoIconAction(icon: 11, label: "Room topic: " + topic) { choosingTopic = true }
                }
                if topic != "All" {
                    HStack {
                        Text(topic).font(.custom("AvenirNext-DemiBold", size: 12)).foregroundStyle(KokoInk.accent)
                        Spacer()
                        KokoIconAction(icon: 6, label: "Clear topic filter") { topic = "All" }
                    }
                }
                LazyVStack(spacing: 26) {
                    ForEach(filtered) { room in KokoVoiceRoomCard(room: room) }
                }
                if filtered.isEmpty {
                    KokoEmpty(title: "No rooms here yet", detail: "Choose another topic or start a room of your own.", art: 1)
                    KokoAction(title: "Create a voice room", icon: 7) { navigation.open(.createRoom(false)) }
                }
                KokoMenuRow(title: "Room ranking", icon: 15) { navigation.open(.ranking) }
                LocalPreviewNote(text: "LOCAL ROOM PREVIEWS · NO AUDIO IS BROADCAST")
            }
            .allowsHitTesting(!choosingTopic)
            .accessibilityHidden(choosingTopic)
            if choosingTopic {
                KokoModal(title: "Room topics", dismiss: { choosingTopic = false }) {
                    ForEach(KokoCommunity.topics, id: \.self) { option in
                        KokoAction(title: option == "All" ? "All topics" : option, emphasis: topic == option) {
                            topic = option; choosingTopic = false
                        }
                    }
                }
            }
        }
    }
}

struct KokoVoiceRoomCard: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    let room: ListeningRoom
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button { navigation.open(.room(room.id)) } label: {
                KokoRoomHostCover(room: room).frame(height: 248)
            }.buttonStyle(KokoPressStyle()).accessibilityLabel("Enter voice room preview: " + room.roomTitle)
            VStack(alignment: .leading, spacing: 7) {
                Text(room.conversationTopic.uppercased())
                    .font(.custom("AvenirNext-DemiBold", size: 10)).tracking(1.2).foregroundStyle(KokoInk.accent)
                Text(room.roomTitle).font(.custom("AvenirNext-Bold", size: 22, relativeTo: .title2))
                    .fixedSize(horizontal: false, vertical: true)
                if !room.conversationPrompt.isEmpty {
                    Text(room.conversationPrompt).font(.custom("AvenirNext-Regular", size: 13))
                        .foregroundStyle(KokoInk.secondary).lineLimit(2)
                }
            }
            HStack(spacing: 12) {
                if let host = community.member(room.hostMemberID) {
                    Button { navigation.open(.profile(host.id)) } label: {
                        HStack(spacing: 10) {
                            KokoMemberPortrait(member: host).frame(width: 52, height: 52)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(host.publicName).font(.custom("AvenirNext-DemiBold", size: 14)).lineLimit(1)
                                Text("Room host").font(.custom("AvenirNext-Regular", size: 11)).foregroundStyle(KokoInk.secondary)
                            }
                        }
                    }.buttonStyle(KokoPressStyle()).accessibilityLabel("View host " + host.publicName)
                }
                Spacer(minLength: 0)
                KokoAction(title: "Enter", icon: 1) { navigation.open(.room(room.id)) }
                    .fixedSize(horizontal: true, vertical: false)
            }
        }.foregroundStyle(KokoInk.primary)
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
    var body: some View {
        KokoPage(title: videoStage ? "Create a live room" : "Create a voice room", subtitle: "Give people a reason to stay.", back: navigation.back) {
            if let host = community.currentMember {
                KokoMemberCoverPhoto(member: host).frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else { KokoPhotoPlaceholder().frame(height: 220) }
            Text("Your profile photo is your room cover.")
                .font(.custom("AvenirNext-Regular", size: 13)).foregroundStyle(KokoInk.secondary)
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
                let room = ListeningRoom(id: UUID().uuidString, roomTitle: title, conversationPrompt: conversationPrompt, hostMemberID: community.myID, conversationTopic: topic, seatLimit: Int(seats) ?? 6, isPublicRoom: publicRoom, isVideoStage: videoStage, artworkTile: videoStage ? 1 : 0, targetAudience: audience, seatAssignments: [0: community.myID], mutedSeatNumbers: [0])
                if community.saveRoom(room, creating: true) { navigation.back(); navigation.open(.room(room.id)) }
            }
        }
    }
}
