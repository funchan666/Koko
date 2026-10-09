import SwiftUI

struct KokoRoomDirectory: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @State private var topic = "All"
    @State private var audience = "Voice rooms"
    @State private var search = ""
    @State private var choosingTopic = false
    private let roomColumns = [
        GridItem(.adaptive(minimum: 150, maximum: 260), spacing: 14, alignment: .top)
    ]
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
                KokoSectionTitle(title: "Voice rooms", detail: "\(filtered.count) previews")
                LazyVGrid(columns: roomColumns, spacing: 14) {
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

private struct KokoVoiceRoomCover: View {
    let room: ListeningRoom
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Artwork(sheet: .social, tile: 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(KokoInk.panel)
                .clipped()
            LinearGradient(
                colors: [Color.black.opacity(0.64), Color.clear, KokoInk.canvas.opacity(0.18)],
                startPoint: .bottomLeading,
                endPoint: .topTrailing
            )
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Artwork(sheet: .navigation, tile: 1, ink: KokoInk.accent).frame(width: 18, height: 18)
                    Text("VOICE ROOM").tracking(1.1)
                    Text("/ PREVIEW").foregroundStyle(KokoInk.secondary)
                }
                .font(.custom("AvenirNext-Bold", size: 9, relativeTo: .caption2))
                .foregroundStyle(KokoInk.primary)
                Text(room.conversationTopic.uppercased())
                    .font(.custom("AvenirNext-DemiBold", size: 10, relativeTo: .caption2))
                    .tracking(1.3)
                    .foregroundStyle(KokoInk.accent)
            }
            .padding(12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(KokoInk.accent.opacity(0.35), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}

struct KokoVoiceRoomCard: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    let room: ListeningRoom
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button { navigation.open(.room(room.id)) } label: {
                KokoVoiceRoomCover(room: room).frame(height: 148)
            }.buttonStyle(KokoPressStyle()).accessibilityLabel("Enter voice room preview: " + room.roomTitle)
            VStack(alignment: .leading, spacing: 9) {
                Text(room.roomTitle).font(.custom("AvenirNext-Bold", size: 16, relativeTo: .headline))
                    .fixedSize(horizontal: false, vertical: true)
                if !room.conversationPrompt.isEmpty {
                    Text(room.conversationPrompt).font(.custom("AvenirNext-Regular", size: 11, relativeTo: .caption))
                        .foregroundStyle(KokoInk.secondary).lineLimit(2)
                }
                if let host = community.member(room.hostMemberID) {
                    Button { navigation.open(.profile(host.id)) } label: {
                        HStack(spacing: 7) {
                            KokoMemberPortrait(member: host).frame(width: 30, height: 30)
                            Text(host.publicName).font(.custom("AvenirNext-DemiBold", size: 11)).lineLimit(1)
                        }
                    }.buttonStyle(KokoPressStyle()).accessibilityLabel("View host " + host.publicName)
                }
                HStack(spacing: 6) {
                    KokoSocialTag(title: "Voice")
                    Spacer(minLength: 0)
                    Text("Preview").font(.custom("AvenirNext-Medium", size: 10, relativeTo: .caption2)).foregroundStyle(KokoInk.secondary)
                }
            }
        }
        .padding(10)
        .foregroundStyle(KokoInk.primary)
        .background(ArtworkSurface(tile: 2))
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
