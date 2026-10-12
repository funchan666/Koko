import SwiftUI

// Home is a video-room directory; recorded media has its own collection.
struct KokoDiscoverView: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @State private var roomAudience = "Live rooms"
    @State private var roomTopic = "All"
    @State private var roomCategory = "For you"
    @State private var roomSearch = ""
    @State private var choosingTopic = false

    private var visibleRooms: [HostedConversationRoom] {
        let query = roomSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        return community.rooms.filter { room in
            room.isVideoStage
                && (roomAudience == "Live rooms" || community.following.contains(room.hostMemberID))
                && (roomTopic == "All" || room.conversationTopic == roomTopic)
                && (query.isEmpty || (room.roomTitle + " " + room.conversationTopic + " "
                    + (community.member(room.hostMemberID)?.publicName ?? "")).localizedCaseInsensitiveContains(query))
        }
    }

    private var featuredMoments: [SharedMoment] {
        let liveAssetIDs = KokoMediaLibrary.liveRoomPreviewAssetIDs
        let availableMoments = community.moments.filter { moment in
            guard let asset = moment.mediaAsset else { return true }
            return !liveAssetIDs.contains(asset.id)
        }
        let videos = availableMoments.filter { $0.mediaAsset?.isVideo == true }
        let photos = availableMoments.filter { $0.mediaAsset?.isVideo != true }
        return Array((videos.prefix(3) + photos.prefix(3)))
    }

    private let roomColumns = [
        GridItem(.flexible(minimum: 0), spacing: 12, alignment: .top),
        GridItem(.flexible(minimum: 0), spacing: 12, alignment: .top)
    ]

    private func selectCategory(_ category: String) {
        roomCategory = category
        if category == "Following" {
            roomAudience = "Following"
            roomTopic = "All"
        } else if category == "For you" {
            roomAudience = "Live rooms"
            roomTopic = "All"
        } else {
            roomAudience = "Live rooms"
            roomTopic = category
        }
    }

    var body: some View {
        GeometryReader { viewport in
            ZStack {
            KokoPage {
                VStack(spacing: 12) {
                    KokoLiveDirectoryHero {
                        navigation.open(.createRoom(true))
                    }
                    KokoSearchField(prompt: "Search the live floor", query: $roomSearch, usesCompactLayout: true)
                        .frame(minWidth: 0, maxWidth: .infinity)
                    KokoDiscoverCategoryRail(selection: $roomCategory) { category in
                        selectCategory(category)
                    }
                }
                KokoLiveSectionHeading(category: roomCategory)
                LazyVGrid(columns: roomColumns, spacing: 14) {
                    ForEach(visibleRooms) { room in KokoLiveRoomCard(room: room) }
                }
                .frame(minWidth: 0, maxWidth: .infinity)
                if visibleRooms.isEmpty {
                    KokoEmpty(title: "No rooms here yet", detail: "Try another topic or create your own live room.", art: 1)
                    KokoAction(title: "Create a live room", icon: 0) { navigation.open(.createRoom(true)) }
                }
                KokoConversationDiscoveryInvitation()
                KokoUpdatesSectionHeading()
                LazyVGrid(columns: roomColumns, spacing: 14) {
                    ForEach(featuredMoments) { moment in
                        KokoMomentCard(moment: moment)
                    }
                }
                KokoUpdatesBrowseCard() {
                    navigation.open(.momentsCollection)
                }
                KokoHostsStrip(cardWidth: min(292, max(228, (viewport.size.width - 40) * 0.84)))
                KokoDiscoverActionCards()
            }
            .allowsHitTesting(!choosingTopic)
            .accessibilityHidden(choosingTopic)
            if choosingTopic {
                KokoModal(title: "Room topics", presentation: .selection, dismiss: { choosingTopic = false }) {
                    ForEach(KokoCommunity.topics, id: \.self) { topic in
                        KokoAction(title: topic == "All" ? "All topics" : topic, emphasis: roomTopic == topic) {
                            roomTopic = topic
                            roomAudience = "Live rooms"
                            roomCategory = topic == "All" ? "For you" : topic
                            choosingTopic = false
                        }
                    }
                }
            }
            }
            .frame(width: viewport.size.width, height: viewport.size.height, alignment: .top)
            .clipped()
        }
    }
}

private struct KokoUpdatesBrowseCard: View {
    @Environment(\.dynamicTypeSize) private var textSize
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            let layout = textSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                : AnyLayout(HStackLayout(alignment: .center, spacing: 16))
            layout {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Little moments, real connections")
                        .font(KokoTypography.heading(size: 19, relativeTo: .headline))
                    Text("Find a story worth saying hello to.")
                        .font(KokoTypography.medium(size: 12, relativeTo: .subheadline))
                        .foregroundStyle(KokoInk.canvas.opacity(0.72))
                    Text("Open the feed →")
                        .font(KokoTypography.emphasis(size: 12, relativeTo: .subheadline))
                        .padding(.top, 5)
                }.fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image("KokoDiscoverFeedObject").resizable().scaledToFit()
                    .frame(width: 76, height: 82).accessibilityHidden(true)
            }
            .foregroundStyle(KokoInk.canvas)
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
            .background { Image("KokoCollectionMintSurface").resizable().accessibilityHidden(true) }
            .contentShape(Rectangle())
        }.buttonStyle(KokoPressStyle())
    }
}

private struct KokoHostsStrip: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @Environment(\.dynamicTypeSize) private var textSize
    let cardWidth: CGFloat
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("A shared interest. A first hello.")
                    .font(KokoTypography.heading(size: 21, relativeTo: .title2))
                    .accessibilityAddTraits(.isHeader)
                Text("Meet the people behind the rooms.")
                    .font(KokoTypography.medium(size: 12, relativeTo: .subheadline))
                    .foregroundStyle(KokoInk.secondary)
            }.fixedSize(horizontal: false, vertical: true)
            if textSize.isAccessibilitySize {
                VStack(spacing: 12) {
                    ForEach(community.members) { KokoDiscoverHostInvitation(member: $0) }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(community.members) { member in
                            KokoDiscoverHostInvitation(member: member).frame(width: cardWidth)
                        }
                    }
                }
            }
        }.padding(.vertical, 6).frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct KokoDiscoverHostInvitation: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    let member: CommunityMember
    private var following: Bool { community.following.contains(member.id) }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { navigation.open(.profile(member.id)) } label: {
                HStack(alignment: .center, spacing: 12) {
                    KokoMemberPortrait(member: member)
                        .frame(width: 66, height: 74)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(verbatim: member.publicName)
                            .font(KokoTypography.heading(size: 17, relativeTo: .headline))
                        if let topic = member.interests.first {
                            Text(LocalizedStringKey(topic))
                                .font(KokoTypography.emphasis(size: 12, relativeTo: .caption))
                                .foregroundStyle(KokoInk.canvas.opacity(0.72))
                        }
                        Text("View profile →")
                            .font(KokoTypography.medium(size: 11, relativeTo: .caption))
                    }.fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(KokoPressStyle())
            Text(verbatim: member.introductionLine)
                .font(KokoTypography.medium(size: 12, relativeTo: .subheadline))
                .foregroundStyle(KokoInk.canvas.opacity(0.8))
                .lineLimit(2, reservesSpace: true)
            HStack(spacing: 10) {
                Button { community.toggleFollow(member.id) } label: {
                    Text(LocalizedStringKey(following ? "Followed" : "Follow"))
                        .font(KokoTypography.emphasis(size: 12, relativeTo: .subheadline))
                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8).padding(.vertical, 10)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background { Image("KokoCollectionMintSurface").resizable().accessibilityHidden(true) }
                }.buttonStyle(KokoPressStyle())
                    .accessibilityAddTraits(following ? .isSelected : [])
                Button { navigation.open(.conversation(member.id)) } label: {
                    Text("Say hello →")
                        .font(KokoTypography.heading(size: 12, relativeTo: .subheadline))
                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                }.buttonStyle(KokoPressStyle())
            }
        }
        .foregroundStyle(KokoInk.canvas)
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background { Image("KokoDiscoverInvitationPaper").resizable().accessibilityHidden(true) }
    }
}

private struct KokoDiscoverActionCards: View {
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @Environment(\.dynamicTypeSize) private var textSize
    var body: some View {
        let layout = textSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        layout {
            actionCard(title: "Find your people", detail: "Start with a shared interest", image: "KokoDiscoverPeopleObject") {
                navigation.open(.search)
            }
            actionCard(title: "Start a voice room", detail: "Make room for a good conversation", image: "KokoDiscoverRoomObject") {
                navigation.open(.createRoom(false))
            }
        }
    }
    private func actionCard(title: String, detail: String, image: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(image).resizable().scaledToFit()
                    .frame(width: 58, height: 58).accessibilityHidden(true)
                Text(LocalizedStringKey(title))
                    .font(KokoTypography.heading(size: 15, relativeTo: .headline))
                    .lineLimit(2, reservesSpace: true)
                Text(LocalizedStringKey(detail))
                    .font(KokoTypography.medium(size: 11, relativeTo: .subheadline))
                    .foregroundStyle(KokoInk.secondary)
                    .lineLimit(2, reservesSpace: true)
            }.frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
                .padding(.horizontal, 8).padding(.vertical, 6)
                .contentShape(Rectangle())
        }.buttonStyle(KokoPressStyle())
    }
}

/// Uses the host's supplied photograph, never a film thumbnail presented as a live stream.
struct KokoRoomHostCover: View {
    @EnvironmentObject private var community: CommunityJournalStore
    let room: HostedConversationRoom
    var body: some View {
        Group {
            if let host = community.member(room.hostMemberID) {
                KokoMemberCoverPhoto(member: host)
            } else { KokoPhotoPlaceholder() }
        }
        .frame(maxWidth: .infinity)
        .clipped()
        .overlay(alignment: .topLeading) {
            HStack(spacing: 6) {
                Artwork(sheet: .navigation, tile: room.isVideoStage ? 0 : 1, ink: KokoInk.accent).frame(width: 20, height: 20)
                Text(LocalizedStringKey(room.isVideoStage ? "LIVE ROOM" : "VOICE ROOM")).tracking(1)
                Text("/ PREVIEW").foregroundStyle(KokoInk.secondary)
            }
            .font(KokoTypography.heading(size: 10))
            .foregroundStyle(KokoInk.primary)
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(KokoControlSurface()).padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityLabel(Text(LocalizedStringKey(room.isVideoStage ? "Live room preview cover. No broadcast is connected." : "Voice room preview cover. No audio is broadcast.")))
    }
}

private struct KokoLiveDirectoryHero: View {
    @ScaledMetric(relativeTo: .body) private var bannerHeight: CGFloat = 170
    let create: () -> Void
    var body: some View {
        GeometryReader { bounds in
            // Native copy occupies only the blank left side of the original artwork.
            let copyWidth = max(0, bounds.size.width * 0.56 - 32)
            VStack(alignment: .leading, spacing: 6) {
                Text("GOOD COMPANY")
                    .font(KokoTypography.emphasis(size: 9, relativeTo: .caption2))
                    .tracking(1.1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text("Come say\nhello.")
                    .font(KokoTypography.heading(size: 24, relativeTo: .title2))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Button(action: create) {
                    Text("Start a room →")
                        .font(KokoTypography.heading(size: 11.5, relativeTo: .caption))
                        .foregroundStyle(KokoInk.paper)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 10)
                        .frame(width: min(124, copyWidth), height: 44)
                        .background {
                            Image("KokoLiveHelloAction").resizable().accessibilityHidden(true)
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(KokoPressStyle())
                .accessibilityLabel("Create a video room")
            }
            .foregroundStyle(KokoInk.onMint)
            .frame(width: copyWidth, height: bounds.size.height - 32, alignment: .leading)
            .padding(16)
        }
        .frame(height: bannerHeight)
        .background {
            Image("KokoLiveHelloBanner").resizable().accessibilityHidden(true)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct KokoDiscoverCategoryRail: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var selection: String
    let select: (String) -> Void
    private let categories: [(value: String, label: String, artwork: String)] = [
        ("For you", "For you", "KokoDiscoverForYou"),
        ("Following", "Following", "KokoDiscoverFollowing"),
        ("Conversation", "Chat", "KokoDiscoverConversation"),
        ("Music", "Music", "KokoDiscoverMusic"),
        ("Creative", "Creative", "KokoDiscoverCreative"),
        ("After hours", "After hours", "KokoDiscoverAfterHours")
    ]
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 0), spacing: 6),
              count: dynamicTypeSize.isAccessibilitySize ? 2 : 3)
    }
    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(categories, id: \.value) { category in
                Button { select(category.value) } label: {
                    HStack(spacing: 5) {
                        Image(category.artwork)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 21, height: 21)
                            .accessibilityHidden(true)
                        Text(LocalizedStringKey(category.label))
                            .font(KokoTypography.emphasis(size: 11.5, relativeTo: .caption))
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                            .minimumScaleFactor(0.9)
                            .foregroundStyle(selection == category.value ? KokoInk.onMint : KokoInk.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background {
                        if selection == category.value {
                            Image("KokoVoiceTopicSelection")
                                .resizable()
                                .accessibilityHidden(true)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(KokoPressStyle())
                .accessibilityLabel(Text(LocalizedStringKey(category.value)))
                .accessibilityAddTraits(selection == category.value ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct KokoLiveSectionHeading: View {
    let category: String
    var body: some View {
        HStack(spacing: 11) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Live rooms").font(KokoTypography.heading(size: 20, relativeTo: .title3))
                Text(LocalizedStringKey(category == "For you" ? "A room for your mood" : category))
                    .font(KokoTypography.medium(size: 10)).foregroundStyle(KokoInk.secondary)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct KokoLiveRoomCard: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @ScaledMetric(relativeTo: .body) private var directoryCoverHeight: CGFloat = 185.5
    @ScaledMetric(relativeTo: .body) private var directoryDetailsHeight: CGFloat = 124
    let room: HostedConversationRoom
    private var host: CommunityMember? { community.member(room.hostMemberID) }
    private var recordedPreview: CommunityMediaAsset? { KokoMediaLibrary.liveRoomPreview(for: room.id) }

    var body: some View {
        Group {
            KokoRoomEditorialLayout(title: room.roomTitle, topic: room.conversationTopic,
                                    hostName: host?.publicName ?? "Koko", invitation: "Enter room →",
                                    cardHeight: directoryCoverHeight + directoryDetailsHeight,
                                    coverShare: directoryCoverHeight / (directoryCoverHeight + directoryDetailsHeight),
                                    compactRoomDetails: true,
                                    openContent: { navigation.open(.room(room.id)) },
                                    openProfile: { navigation.open(.profile(room.hostMemberID)) }) {
                ZStack(alignment: .topLeading) {
                    if let preview = recordedPreview {
                        KokoContentImage(asset: preview)
                    } else if let host {
                        KokoMemberCoverPhoto(member: host)
                    } else {
                        KokoPhotoPlaceholder()
                    }
                    KokoBroadcastRoomBadge(hasRecordedPreview: recordedPreview != nil, showsStatusDetail: false)
                        .modifier(KokoRoomSignalBreathing())
                        .padding(.leading, 9).padding(.top, 9)
                }
            }
        }
        .buttonStyle(KokoPressStyle())
        .accessibilityLabel("Open video room preview: \(room.roomTitle), hosted by \(host?.publicName ?? "Koko")")
    }
}

/// Artwork is a full original bitmap. Explicit geometry keeps media and text from
/// proposing a wider size to the two-column directory.
struct KokoRoomEditorialLayout<Cover: View>: View {
    let title: String
    let topic: String
    let hostName: String
    let invitation: String
    var cardHeight: CGFloat = 380
    var coverShare: CGFloat = 0.554
    var compactRoomDetails = false
    let openContent: () -> Void
    let openProfile: () -> Void
    @ViewBuilder var cover: Cover

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                Button(action: openContent) { cover }.buttonStyle(KokoPressStyle())
                    .frame(width: geometry.size.width, height: geometry.size.height * coverShare)
                    .clipped()
                if compactRoomDetails {
                    compactDetails
                        .frame(width: geometry.size.width, height: geometry.size.height * (1 - coverShare))
                } else {
                    standardDetails
                        .frame(width: geometry.size.width, height: geometry.size.height * (1 - coverShare), alignment: .topLeading)
                }
            }
            .background { Image("KokoRoomEditorialCard").resizable().accessibilityHidden(true) }
            .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
        }
        .frame(height: cardHeight)
        .frame(minWidth: 0, maxWidth: .infinity)
    }

    private var compactDetails: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: openContent) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(LocalizedStringKey(topic))
                        .font(KokoTypography.emphasis(size: 10, relativeTo: .caption))
                        .foregroundStyle(KokoInk.canvas.opacity(0.7)).lineLimit(1)
                    Text(verbatim: title)
                        .font(KokoTypography.heading(size: 16, relativeTo: .headline))
                        .lineLimit(2).multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .contentShape(Rectangle())
            }.buttonStyle(KokoPressStyle())
            HStack(spacing: 6) {
                Button(action: openProfile) {
                    Text(verbatim: hostName)
                        .font(KokoTypography.medium(size: 11, relativeTo: .caption))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }.buttonStyle(KokoPressStyle())
                    .accessibilityLabel(Text(verbatim: hostName))
                Button(action: openContent) {
                    Text(LocalizedStringKey(invitation))
                        .font(KokoTypography.heading(size: 10, relativeTo: .caption))
                        .lineLimit(1).minimumScaleFactor(0.85)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }.buttonStyle(KokoPressStyle())
            }
        }
        .foregroundStyle(KokoInk.canvas)
        .padding(.horizontal, 12).padding(.vertical, 10)
    }

    private var standardDetails: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(LocalizedStringKey(topic))
                .font(KokoTypography.emphasis(size: 10))
                .foregroundStyle(KokoInk.canvas.opacity(0.7))
                .lineLimit(1)
            Button(action: openContent) { Text(verbatim: title) }.buttonStyle(KokoPressStyle())
                .font(KokoTypography.heading(size: 16))
                .lineLimit(2)
                .frame(height: 43, alignment: .topLeading)
            Button(action: openProfile) { Text(verbatim: hostName).frame(minHeight: 44, alignment: .leading) }.buttonStyle(KokoPressStyle())
                .font(KokoTypography.medium(size: 11))
                .lineLimit(1)
            Spacer(minLength: 3)
            Button(action: openContent) { Text(LocalizedStringKey(invitation)) }.buttonStyle(KokoPressStyle())
                .font(KokoTypography.heading(size: 11))
                .lineLimit(1)
        }
        .foregroundStyle(KokoInk.canvas)
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 15)
    }
}

struct KokoMomentsCollection: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @State private var mediaFormat = "All"
    @State private var collectionTopic = "All"
    @State private var followedCreatorsOnly = false
    @State private var choosingFilters = false
    private var visibleMoments: [SharedMoment] {
        community.moments.filter { moment in
            (mediaFormat == "All" || (mediaFormat == "Videos" ? moment.mediaAsset?.isVideo == true : moment.mediaAsset?.isVideo == false))
                && (collectionTopic == "All" || moment.topicLabel == collectionTopic)
                && (!followedCreatorsOnly || community.following.contains(moment.creatorMemberID))
                && !KokoMediaLibrary.liveRoomPreviewAssetIDs.contains(moment.mediaAsset?.id ?? "")
        }
    }
    var body: some View {
        ZStack {
            KokoPage(title: "Photos & videos", back: navigation.back) {
                HStack {
                    KokoAction(title: "Create a post") { navigation.open(.composeMoment) }
                    KokoAction(title: "My submissions", emphasis: false) { navigation.open(.pendingMoments) }
                }
                HStack(spacing: 10) {
                    KokoChoiceRail(choices: ["All", "Photos", "Videos"], selection: $mediaFormat)
                    KokoIconAction(icon: 11, label: "Filter the collection") { choosingFilters = true }
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12, alignment: .top), GridItem(.flexible(), spacing: 12, alignment: .top)], spacing: 16) {
                    ForEach(visibleMoments) { moment in KokoMomentCard(moment: moment) }
                }
                if visibleMoments.isEmpty {
                    KokoEmpty(title: "Nothing here yet", detail: "Choose another collection or change your filters.")
                }
            }
            .allowsHitTesting(!choosingFilters)
            .accessibilityHidden(choosingFilters)
            if choosingFilters {
                KokoModal(title: "Collection filters", presentation: .selection, dismiss: { choosingFilters = false }) {
                    KokoToggleRow(title: "Following only", enabled: $followedCreatorsOnly)
                    KokoChoiceRail(choices: KokoCommunity.topics, selection: $collectionTopic)
                    KokoAction(title: "Show collection") { choosingFilters = false }
                    KokoAction(title: "Reset filters", emphasis: false) {
                        collectionTopic = "All"; followedCreatorsOnly = false; choosingFilters = false
                    }
                }
            }
        }
    }
}

private struct KokoUpdatesSectionHeading: View {
    @EnvironmentObject private var community: CommunityJournalStore
    private var videoCount: Int {
        community.moments.filter {
            $0.mediaAsset?.isVideo == true
                && !KokoMediaLibrary.liveRoomPreviewAssetIDs.contains($0.mediaAsset?.id ?? "")
        }.count
    }
    var body: some View {
        HStack(spacing: 11) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Community updates").font(KokoTypography.heading(size: 20, relativeTo: .title3))
                Text("\(videoCount) videos · photos from your people").font(KokoTypography.medium(size: 10)).foregroundStyle(KokoInk.secondary)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct KokoMomentCard: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    let moment: SharedMoment
    var body: some View {
        VStack(spacing: 5) {
            KokoRoomEditorialLayout(
                title: moment.captionLine,
                topic: moment.mediaAsset.map { $0.isVideo ? "Video · \($0.durationLabel)" : "Photo" } ?? moment.topicLabel,
                hostName: community.member(moment.creatorMemberID)?.publicName ?? "Koko",
                invitation: "View moment →",
                openContent: { navigation.open(.moment(moment.id)) },
                openProfile: { navigation.open(.profile(moment.creatorMemberID)) }
            ) {
                if let asset = moment.mediaAsset {
                    KokoContentImage(asset: asset)
                } else {
                    KokoPhotoPlaceholder()
                }
            }
            HStack(spacing: 8) {
                Button { community.toggleMomentLike(moment.id) } label: {
                    VStack(spacing: 2) {
                        Text("\(community.momentLikeCount(moment.id))")
                        Text(LocalizedStringKey(community.journal?.likedMomentKeys.contains(moment.id) == true ? "Liked" : "Like"))
                    }.frame(maxWidth: .infinity, minHeight: 44)
                }.buttonStyle(KokoPressStyle())
                Button { navigation.open(.moment(moment.id)) } label: {
                    VStack(spacing: 2) {
                        Text("\(community.comments(for: moment.id).count)")
                        Text("Comments")
                    }.frame(maxWidth: .infinity, minHeight: 44)
                }.buttonStyle(KokoPressStyle())
            }.font(KokoTypography.emphasis(size: 11)).foregroundStyle(KokoInk.accent)
        }.buttonStyle(KokoPressStyle())
            .accessibilityLabel(moment.mediaAsset?.isVideo == true ? "Open video update: " + moment.captionLine : "Open photo update: " + moment.captionLine)
    }
}

struct KokoRoomCard: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    let room: HostedConversationRoom
    var body: some View {
        Group {
            HStack(alignment: .center, spacing: 15) {
                if let host = community.member(room.hostMemberID) {
                    KokoProfileLink(memberID: host.id) { KokoMemberPortrait(member: host).frame(width: 88, height: 104) }
                } else { KokoPhotoPlaceholder().frame(width: 88, height: 104) }
                Button { navigation.open(.room(room.id)) } label: { VStack(alignment: .leading, spacing: 6) {
                    Text(LocalizedStringKey(room.conversationTopic)).font(KokoTypography.emphasis(size: 10)).tracking(1).foregroundStyle(KokoInk.accent)
                    Text(room.roomTitle).font(KokoTypography.heading(size: 17, relativeTo: .headline)).fixedSize(horizontal: false, vertical: true)
                    Text(room.conversationPrompt).font(KokoTypography.body(size: 12)).foregroundStyle(KokoInk.secondary).lineLimit(2)
                    Text("\(room.seatAssignments.count)/\(room.seatLimit) seats · \(room.isVideoStage ? "Video" : "Voice") preview").font(KokoTypography.medium(size: 10))
                }
                }.buttonStyle(KokoPressStyle())
                Spacer(minLength: 0)
            }.foregroundStyle(KokoInk.primary).padding(14).frame(maxWidth: .infinity, alignment: .leading).background(ArtworkSurface())
        }.buttonStyle(KokoPressStyle())
    }
}

struct KokoDiscoverySearch: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @State private var searchWords = ""
    @State private var resultKind = "All"
    @State private var topic = "All"
    @State private var filtersVisible = false
    @State private var language = "Any language"
    @State private var region = "Any region"
    @State private var gender = "Any gender"
    @State private var minimumAge = "18"
    @State private var maximumAge = "99"
    private func matches(_ text: String) -> Bool { searchWords.isEmpty || text.localizedCaseInsensitiveContains(searchWords) }
    private func accepts(_ member: CommunityMember) -> Bool {
        member.adultAge >= (Int(minimumAge) ?? 18) && member.adultAge <= (Int(maximumAge) ?? 99)
        && (language == "Any language" || member.spokenLanguage == language)
        && (region == "Any region" || member.hometownLabel == region)
        && (gender == "Any gender" || member.genderLabel == gender)
    }
    private var people: [CommunityMember] { community.members.filter { matches($0.publicName + " " + $0.introductionLine) && accepts($0) && (topic == "All" || $0.interests.contains(topic)) } }
    private var rooms: [HostedConversationRoom] { community.rooms.filter { room in matches(room.roomTitle + " " + room.conversationPrompt) && (topic == "All" || room.conversationTopic == topic) && community.member(room.hostMemberID).map(accepts) == true } }
    private var moments: [SharedMoment] { community.moments.filter { moment in matches(moment.captionLine) && (topic == "All" || moment.topicLabel == topic) && community.member(moment.creatorMemberID).map(accepts) == true } }
    var body: some View {
        ZStack {
            KokoPage(title: "Find your people", subtitle: "Follow a curiosity.", back: navigation.back) {
                HStack { KokoSearchField(prompt: "People, rooms, moments", query: $searchWords); KokoIconAction(icon: 11, label: "Filters") { filtersVisible = true } }
                KokoChoiceRail(choices: ["All", "People", "Rooms", "Moments"], selection: $resultKind)
                KokoChoiceRail(choices: KokoCommunity.topics, selection: $topic)
                if resultKind == "All" || resultKind == "People" {
                    Text("People · \(people.count)").font(KokoTypography.heading(size: 19))
                    ForEach(people) { member in KokoMemberRow(member: member) }
                }
                if resultKind == "All" || resultKind == "Rooms" {
                    Text("Rooms · \(rooms.count)").font(KokoTypography.heading(size: 19))
                    ForEach(rooms) { room in KokoRoomCard(room: room) }
                }
                if resultKind == "All" || resultKind == "Moments" {
                    Text("Moments · \(moments.count)").font(KokoTypography.heading(size: 19))
                    ForEach(moments) { moment in KokoMomentCard(moment: moment) }
                }
                if (resultKind == "People" && people.isEmpty) || (resultKind == "Rooms" && rooms.isEmpty) || (resultKind == "Moments" && moments.isEmpty) || (people.isEmpty && rooms.isEmpty && moments.isEmpty) {
                    KokoEmpty(title: "No matches just yet", detail: "Try another word or widen your filters.")
                }
            }
            if filtersVisible {
                KokoModal(title: "Make it your kind", presentation: .selection, dismiss: { filtersVisible = false }) {
                    HStack { KokoField(label: "Minimum age", value: $minimumAge, keyboard: .numberPad); KokoField(label: "Maximum age", value: $maximumAge, keyboard: .numberPad) }
                    KokoChoiceRail(choices: ["Any gender", "Woman", "Man", "Non-binary"], selection: $gender)
                    KokoChoiceRail(choices: ["Any language", "English", "Portuguese", "French", "Spanish", "Mandarin"], selection: $language)
                    KokoChoiceRail(choices: ["Any region", "Bristol", "Lisbon", "Melbourne", "Chicago"], selection: $region)
                    KokoAction(title: "Show results") {
                        guard let min = Int(minimumAge), let max = Int(maximumAge), min >= 18, max <= 99, min <= max else { community.notice = "Choose an age range from 18 to 99, with the minimum no greater than the maximum."; return }
                        filtersVisible = false
                    }
                    KokoAction(title: "Reset filters", emphasis: false) { minimumAge = "18"; maximumAge = "99"; gender = "Any gender"; language = "Any language"; region = "Any region" }
                }
            }
        }
    }
}

struct KokoMemberRow: View {
    @EnvironmentObject private var navigation: KokoSceneNavigation
    let member: CommunityMember
    var body: some View {
        Button { navigation.open(.profile(member.id)) } label: {
            HStack(spacing: 14) {
                KokoMemberPortrait(member: member).frame(width: 58, height: 64)
                VStack(alignment: .leading, spacing: 5) { Text(member.publicName).font(KokoTypography.emphasis(size: 17)); Text("\(member.hometownLabel) · \(member.spokenLanguage)").font(KokoTypography.body(size: 12)).foregroundStyle(KokoInk.secondary) }
                Spacer()
            }.padding(14).background(ArtworkSurface())
        }.buttonStyle(KokoPressStyle())
    }
}

struct KokoSafetyPanel: View {
    @EnvironmentObject private var community: CommunityJournalStore
    let reportedContentID: String
    let memberID: String
    let dismiss: () -> Void
    @State private var reason = ""
    @State private var confirmBlock = false
    var body: some View {
        KokoModal(title: confirmBlock ? "Block this person?" : "Keep your space comfortable", presentation: .safety, dismiss: dismiss) {
            if confirmBlock {
                Text("Their rooms, moments and conversations will be hidden on this device. You can undo this in your blocked list.")
                KokoAction(title: "Block person") { if community.block(memberID) { dismiss() } }
                KokoAction(title: "Go back", emphasis: false) { confirmBlock = false }
            } else {
                ForEach(KokoSafetyReason.all, id: \.self) { option in
                    KokoToggleRow(title: option, enabled: Binding(get: { reason == option }, set: { _ in reason = option }))
                }
                KokoAction(title: "Save report & hide") { if community.report(reportedContentID, reason: reason) { dismiss() } }.disabled(reason.isEmpty)
                if memberID != community.myID { KokoAction(title: "Block this person", emphasis: false) { confirmBlock = true } }
            }
        }
    }
}
