import SwiftUI

struct KokoRoomDirectory: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @State private var topic = "All"
    @State private var audience = "Voice rooms"
    @State private var category = "For you"
    @State private var search = ""
    private var filtered: [HostedConversationRoom] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return community.rooms.filter { room in
            !room.isVideoStage
                && (topic == "All" || room.conversationTopic == topic)
                && (audience == "Voice rooms" || community.following.contains(room.hostMemberID))
                && (query.isEmpty || (room.roomTitle + " " + room.conversationTopic + " "
                    + (community.member(room.hostMemberID)?.publicName ?? "")).localizedCaseInsensitiveContains(query))
        }
    }
    private func selectCategory(_ selected: String) {
        category = selected
        if selected == "Following" {
            audience = "Following"
            topic = "All"
        } else if selected == "For you" {
            audience = "Voice rooms"
            topic = "All"
        } else {
            audience = "Voice rooms"
            topic = selected
        }
    }
    var body: some View {
        KokoPage {
            HStack(spacing: 12) {
                KokoSearchField(prompt: "Search voice rooms", query: $search)
                Button { navigation.open(.createRoom(false)) } label: {
                    Image("KokoStartVoiceRoom").resizable().scaledToFit()
                        .frame(width: 52, height: 52)
                }
                .buttonStyle(KokoPressStyle())
                .accessibilityLabel("Start a voice room")
            }
            KokoVoiceCategoryRail(selection: category, select: selectCategory)
            KokoStudioEntry()
            VStack(alignment: .leading, spacing: 4) {
                Text("Find your conversation")
                    .font(KokoTypography.heading(size: 23, relativeTo: .title2))
                Text("Voice room previews · pick a topic you love")
                    .font(KokoTypography.medium(size: 12, relativeTo: .caption))
                    .foregroundStyle(KokoInk.secondary)
            }
            LazyVStack(spacing: 16) {
                ForEach(filtered) { room in KokoVoiceRoomCard(room: room) }
            }
            if filtered.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Your next conversation starts here")
                        .font(KokoTypography.emphasis(size: 18))
                    Text("Try another topic, or make room for one of your own.")
                        .font(KokoTypography.medium(size: 13))
                        .foregroundStyle(KokoInk.secondary)
                    Button("Start a voice room →") { navigation.open(.createRoom(false)) }
                        .font(KokoTypography.heading(size: 14))
                        .foregroundStyle(KokoInk.accent)
                        .frame(minHeight: 44)
                        .buttonStyle(KokoPressStyle())
                }
                .padding(.vertical, 20)
            }
            KokoConnectionEntry(title: "Need something to talk about?", detail: "Turn a question into a voice room.",
                                artwork: "KokoConversationDeckObject") { navigation.open(.conversationStarters(nil)) }
            HStack {
                Button("Room ranking →") { navigation.open(.ranking) }
                Spacer(minLength: 12)
                Button("Start a room →") { navigation.open(.createRoom(false)) }
            }
            .font(KokoTypography.emphasis(size: 13))
            .foregroundStyle(KokoInk.accent)
            .buttonStyle(KokoPressStyle())
            .frame(minHeight: 44)
        }
    }
}

struct KokoVoiceRoomCard: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @ScaledMetric(relativeTo: .body) private var cardHeight: CGFloat = 188
    let room: HostedConversationRoom
    private var host: CommunityMember? { community.member(room.hostMemberID) }
    var body: some View {
        Group {
            GeometryReader { bounds in
                // These proportions match the new original bitmap seams.
                let portraitWidth = bounds.size.width * 0.378
                let informationWidth = bounds.size.width - portraitWidth
                HStack(spacing: 0) {
                    Group {
                        if let host { KokoProfileLink(memberID: host.id) { KokoMemberCoverPhoto(member: host) } }
                        else { KokoPhotoPlaceholder() }
                    }
                    .frame(width: portraitWidth, height: bounds.size.height)
                    .clipped()
                    VStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image("KokoVoiceSessionWave").resizable().scaledToFit()
                                    .frame(width: 22, height: 18).accessibilityHidden(true)
                                (Text("VOICE · ") + Text(LocalizedStringKey(room.conversationTopic)))
                                    .font(KokoTypography.emphasis(size: 10, relativeTo: .caption))
                                    .foregroundStyle(KokoInk.accent)
                                    .lineLimit(1).minimumScaleFactor(0.8)
                            }
                            Button { navigation.open(.room(room.id)) } label: { Text(room.roomTitle) }.buttonStyle(KokoPressStyle())
                                .font(KokoTypography.heading(size: 18, relativeTo: .headline))
                                .lineLimit(2).minimumScaleFactor(0.85)
                                .frame(maxWidth: .infinity, minHeight: 46, alignment: .topLeading)
                            KokoProfileLink(memberID: room.hostMemberID) { Text("Hosted by \(host?.publicName ?? "Koko")").frame(minHeight: 44) }
                                .font(KokoTypography.medium(size: 11, relativeTo: .caption))
                                .foregroundStyle(KokoInk.secondary)
                                .lineLimit(1).minimumScaleFactor(0.85)
                        }
                        .foregroundStyle(KokoInk.primary)
                        .padding(.horizontal, 14)
                        .frame(width: informationWidth, height: bounds.size.height * 0.73, alignment: .leading)
                        Button { navigation.open(.room(room.id)) } label: { HStack(spacing: 8) {
                            Text("\(room.seatLimit) seats")
                                .font(KokoTypography.medium(size: 10, relativeTo: .caption))
                            Spacer(minLength: 0)
                            Text("Join room →")
                                .font(KokoTypography.heading(size: 12, relativeTo: .caption))
                        }
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .foregroundStyle(KokoInk.onMint)
                        .padding(.horizontal, 14)
                        .frame(width: informationWidth, height: bounds.size.height * 0.27)
                        }.buttonStyle(KokoPressStyle())
                    }
                }
            }
            .frame(height: cardHeight)
            .background { Image("KokoVoiceSessionCard").resizable().accessibilityHidden(true) }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(KokoPressStyle())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Voice room preview, \(room.roomTitle), \(room.conversationTopic), hosted by \(host?.publicName ?? "Koko"), \(room.seatLimit) seats")
        .accessibilityHint("Opens the room; microphone stays off until you choose to enable it")
    }
}

private struct KokoVoiceCategoryRail: View {
    let selection: String
    let select: (String) -> Void
    private let categories = ["For you", "Following", "Conversation", "Music", "Creative", "After hours"]
    private let columns = Array(repeating: GridItem(.flexible(minimum: 0), spacing: 8), count: 3)
    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(categories, id: \.self) { category in
                Button { select(category) } label: {
                    Text(LocalizedStringKey(category))
                        .font(KokoTypography.emphasis(size: 12, relativeTo: .caption))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(selection == category ? KokoInk.onMint : KokoInk.secondary)
                        .padding(.horizontal, 4)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background {
                            if selection == category {
                                Image("KokoVoiceTopicSelection").resizable().accessibilityHidden(true)
                            }
                        }
                }
                .buttonStyle(KokoPressStyle())
                .accessibilityAddTraits(selection == category ? .isSelected : [])
            }
        }
    }
}

struct KokoRoomComposer: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    let videoStage: Bool
    @State private var roomTitle = ""
    @State private var conversationPrompt = ""
    @State private var audienceGoal = "20"
    @State private var topic = "Conversation"
    @State private var seats = "6"
    @State private var publicRoom = true
    init(videoStage: Bool, starter: ConversationStarter? = nil) {
        self.videoStage = videoStage
        _roomTitle = State(initialValue: starter.map { KokoCopy.text($0.roomName) } ?? "")
        _conversationPrompt = State(initialValue: starter.map { KokoCopy.text($0.question) } ?? "")
        _topic = State(initialValue: starter?.topic ?? "Conversation")
    }
    var body: some View {
        KokoPage(title: videoStage ? "Create a live room" : "Create a voice room", subtitle: "Give people a reason to stay.", back: navigation.back) {
            if let host = community.currentMember {
                KokoMemberCoverPhoto(member: host).frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else { KokoPhotoPlaceholder().frame(height: 220) }
            Text("Your profile photo is your room cover.")
                .font(KokoTypography.body(size: 13)).foregroundStyle(KokoInk.secondary)
            KokoField(label: "Room name · up to 50 characters", value: $roomTitle)
            KokoField(label: "What are we talking about?", value: $conversationPrompt, multiline: true)
            KokoField(label: "Audience goal · 1–999", value: $audienceGoal, keyboard: .numberPad)
            KokoChoiceRail(choices: Array(KokoCommunity.topics.dropFirst()), selection: $topic)
            Text("Seats at your table").font(KokoTypography.emphasis(size: 16))
            KokoChoiceRail(choices: ["3", "4", "6", "8", "9", "12"], selection: $seats)
            KokoToggleRow(title: "Public room", enabled: $publicRoom)
            KokoAction(title: "Open my room", icon: 1) {
                let title = roomTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty, title.count <= 50, conversationPrompt.count <= 240, let audience = Int(audienceGoal), (1...999).contains(audience) else { community.notice = "Add a room name up to 50 characters, a description up to 240 characters, and an audience goal from 1 to 999."; return }
                let room = HostedConversationRoom(id: UUID().uuidString, roomTitle: title, conversationPrompt: conversationPrompt, hostMemberID: community.myID, conversationTopic: topic, seatLimit: Int(seats) ?? 6, isPublicRoom: publicRoom, isVideoStage: videoStage, artworkTile: videoStage ? 1 : 0, audienceGoal: audience, seatAssignments: [0: community.myID], mutedSeatNumbers: [0])
                if community.saveRoom(room, creating: true) { navigation.back(); navigation.open(.room(room.id)) }
            }
        }
    }
}
