import SwiftUI

struct KokoRoomDirectory: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @State private var topic = "All"
    @State private var audience = "Voice rooms"
    @State private var category = "For you"
    @State private var search = ""
    @State private var choosingTopic = false
    private let roomColumns = [
        GridItem(.flexible(minimum: 0), spacing: 12, alignment: .top),
        GridItem(.flexible(minimum: 0), spacing: 12, alignment: .top)
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
        ZStack {
            KokoPage {
                HStack(spacing: 10) {
                    KokoSearchField(prompt: "Search voice rooms", query: $search)
                    KokoIconAction(icon: 7, label: "Create a voice room") { navigation.open(.createRoom(false)) }
                }
                KokoVoiceCategoryRail(selection: $category) { selected in
                    selectCategory(selected)
                }
                HStack(spacing: 10) {
                    Text(category == "For you" ? "Find a room with a real hello" : "\(category) conversations")
                        .font(.custom("AvenirNext-DemiBold", size: 12))
                        .foregroundStyle(KokoInk.secondary)
                    Spacer(minLength: 0)
                    KokoIconAction(icon: 11, label: "Room topic: " + topic) { choosingTopic = true }
                        .frame(width: 52)
                }
                KokoVoiceSectionHeading(rooms: filtered)

                LazyVGrid(columns: roomColumns, spacing: 14) {
                    ForEach(filtered) { room in KokoVoiceRoomCard(room: room) }
                }
                if filtered.isEmpty {
                    KokoEmpty(title: "No rooms here yet", detail: "Choose another topic or start a room of your own.", art: 1)
                    KokoAction(title: "Create a voice room", icon: 7) { navigation.open(.createRoom(false)) }
                }
                KokoVoiceCommunityCard {
                    navigation.open(.ranking)
                } create: {
                    navigation.open(.createRoom(false))
                }
            }
            .allowsHitTesting(!choosingTopic)
            .accessibilityHidden(choosingTopic)
            if choosingTopic {
                KokoModal(title: "Room topics", dismiss: { choosingTopic = false }) {
                    ForEach(KokoCommunity.topics, id: \.self) { option in
                        KokoAction(title: option == "All" ? "All topics" : option, emphasis: topic == option) {
                            topic = option
                            audience = "Voice rooms"
                            category = option == "All" ? "For you" : option
                            choosingTopic = false
                        }
                    }
                }
            }
        }
    }
}

private struct KokoVoiceRoomCover: View {
    @EnvironmentObject private var community: CommunityJournalStore
    let room: ListeningRoom
    private var host: CommunityMember? { community.member(room.hostMemberID) }
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let host {
                KokoMemberCoverPhoto(member: host)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                KokoPhotoPlaceholder().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Color.black.opacity(0.18)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    KokoSocialTag(title: "VOICE ROOM", highlighted: true)
                    Spacer(minLength: 0)
                    Text("\(room.seatAssignments.count)/\(room.seatLimit) IN")
                        .font(.custom("AvenirNext-Bold", size: 9)).tracking(0.7)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9).padding(.vertical, 7)
                        .background(Color.black.opacity(0.58)).clipShape(Capsule())
                }
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    Artwork(sheet: .navigation, tile: 1, ink: .white).frame(width: 20, height: 20)
                    Text("LIVE CONVERSATION").font(.custom("AvenirNext-Bold", size: 10)).tracking(1)
                    Spacer(minLength: 0)
                }.foregroundStyle(.white)
            }.padding(13)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(KokoInk.accent.opacity(0.55), lineWidth: 1))
        .accessibilityHidden(true)
    }
}

struct KokoVoiceRoomCard: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    let room: ListeningRoom
    private var host: CommunityMember? { community.member(room.hostMemberID) }
    var body: some View {
        Button { navigation.open(.room(room.id)) } label: {
            VStack(alignment: .leading, spacing: 0) {
                KokoVoiceRoomCover(room: room).frame(height: 166)
                VStack(alignment: .leading, spacing: 9) {
                    Text(room.roomTitle).font(.custom("AvenirNext-Bold", size: 16, relativeTo: .headline))
                        .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                    Text(room.conversationPrompt).font(.custom("AvenirNext-Regular", size: 11, relativeTo: .caption))
                        .foregroundStyle(KokoInk.secondary).lineLimit(2)
                    if let host {
                        HStack(spacing: 7) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Hosted by \(host.publicName)").font(.custom("AvenirNext-DemiBold", size: 11)).lineLimit(1)
                                Text("Open to chat").font(.custom("AvenirNext-Medium", size: 9)).foregroundStyle(KokoInk.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: 8) {
                        Text(room.conversationTopic.uppercased()).font(.custom("AvenirNext-Bold", size: 9)).tracking(0.8)
                            .foregroundStyle(KokoInk.accent)
                            .padding(.horizontal, 9).padding(.vertical, 6)
                            .background(KokoInk.accent.opacity(0.10)).clipShape(Capsule())
                        Spacer(minLength: 0)
                        Text("Join the room →").font(.custom("AvenirNext-Bold", size: 9)).foregroundStyle(KokoInk.coral)
                    }
                }
                .padding(12)
                .frame(height: 190, alignment: .top)
            }
            .foregroundStyle(KokoInk.primary)
            .background(ArtworkSurface(tile: 3))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.16), radius: 12, y: 7)
        }.buttonStyle(KokoPressStyle()).accessibilityLabel("Enter voice room preview: " + room.roomTitle)
    }
}

private struct KokoVoiceCategoryRail: View {
    @Binding var selection: String
    let select: (String) -> Void
    private let categories: [(String, Int)] = [
        ("For you", 0), ("Following", 1), ("Conversation", 2), ("Music", 3), ("Creative", 0), ("After hours", 1)
    ]
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(categories, id: \.0) { category, tile in
                    Button { select(category) } label: {
                        HStack(spacing: 7) {
                            Artwork(sheet: .navigation, tile: [0, 3, 2, 14, 4, 13][tile]).frame(width: 22, height: 22)
                            Text(category).font(.custom("AvenirNext-DemiBold", size: 11)).fixedSize(horizontal: true, vertical: false)
                        }
                        .foregroundStyle(selection == category ? KokoInk.onMint : KokoInk.primary)
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(KokoControlSurface(highlighted: selection == category))
                    }.buttonStyle(KokoPressStyle())
                        .accessibilityAddTraits(selection == category ? .isSelected : [])
                }
            }
        }
    }
}

private struct KokoVoiceSectionHeading: View {
    let rooms: [ListeningRoom]
    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Voice rooms").font(.custom("AvenirNext-Bold", size: 20, relativeTo: .title3))
                Text("Hear people thinking out loud").font(.custom("AvenirNext-Medium", size: 10)).foregroundStyle(KokoInk.secondary)
            }
            Spacer(minLength: 0)
            Text("\(rooms.count) rooms").font(.custom("AvenirNext-Bold", size: 10)).foregroundStyle(KokoInk.coral)
        }
    }
}

private struct KokoVoiceCommunityCard: View {
    let ranking: () -> Void
    let create: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Artwork(sheet: .navigation, tile: 1)
                .frame(width: 25, height: 25)
                .padding(13)
                .background(KokoControlSurface())
            VStack(alignment: .leading, spacing: 3) {
                Text("Make room for a hello").font(.custom("AvenirNext-Bold", size: 15))
                Text("Start a voice room or see who is getting heard.").font(.custom("AvenirNext-Medium", size: 10)).foregroundStyle(KokoInk.secondary).lineLimit(2)
                HStack(spacing: 10) {
                    Button("Open ranking", action: ranking).font(.custom("AvenirNext-Bold", size: 9)).foregroundStyle(KokoInk.coral).buttonStyle(.plain)
                    Button("Create room", action: create).font(.custom("AvenirNext-Bold", size: 9)).foregroundStyle(KokoInk.accent).buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
        }.padding(14).background(ArtworkSurface(tile: 3)).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
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
            KokoAction(title: "Open my room", icon: 1) {
                let title = roomTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty, title.count <= 50, conversationPrompt.count <= 240, let audience = Int(targetAudience), (1...999).contains(audience) else { community.notice = "Add a room name up to 50 characters, a description up to 240 characters, and an audience goal from 1 to 999."; return }
                let room = ListeningRoom(id: UUID().uuidString, roomTitle: title, conversationPrompt: conversationPrompt, hostMemberID: community.myID, conversationTopic: topic, seatLimit: Int(seats) ?? 6, isPublicRoom: publicRoom, isVideoStage: videoStage, artworkTile: videoStage ? 1 : 0, targetAudience: audience, seatAssignments: [0: community.myID], mutedSeatNumbers: [0])
                if community.saveRoom(room, creating: true) { navigation.back(); navigation.open(.room(room.id)) }
            }
        }
    }
}
