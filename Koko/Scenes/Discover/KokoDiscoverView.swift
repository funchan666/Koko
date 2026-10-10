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

    private var visibleRooms: [ListeningRoom] {
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
                KokoLiveDirectoryHero(roomCount: visibleRooms.count) {
                    navigation.open(.createRoom(true))
                }
                KokoSearchField(prompt: "Search the live floor", query: $roomSearch)
                    .frame(minWidth: 0, maxWidth: .infinity)
                KokoDiscoverCategoryRail(selection: $roomCategory) { category in
                    selectCategory(category)
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
                KokoUpdatesSectionHeading()
                LazyVGrid(columns: roomColumns, spacing: 14) {
                    ForEach(featuredMoments) { moment in
                        KokoMomentCard(moment: moment)
                    }
                }
                KokoUpdatesBrowseCard(moments: featuredMoments) {
                    navigation.open(.momentsCollection)
                }
                KokoHostsStrip()
                KokoDiscoverActionCards()
            }
            .allowsHitTesting(!choosingTopic)
            .accessibilityHidden(choosingTopic)
            if choosingTopic {
                KokoModal(title: "Room topics", dismiss: { choosingTopic = false }) {
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
    @EnvironmentObject private var community: CommunityJournalStore
    let moments: [SharedMoment]
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .leading) {
                Image("KokoSocialWidePanelShell")
                    .resizable()
                    .scaledToFill()
                    .accessibilityHidden(true)
                HStack(spacing: 14) {
                    HStack(spacing: -10) {
                        ForEach(Array(moments.prefix(3)), id: \.id) { moment in
                            if let asset = moment.mediaAsset {
                                KokoContentImage(asset: asset)
                                    .frame(width: 52, height: 58)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                        }
                    }
                    .frame(width: 108, height: 62, alignment: .leading)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("See all updates")
                            .font(.custom("AvenirNext-Bold", size: 16))
                        Text("Videos, photos and little moments from the community")
                            .font(.custom("AvenirNext-Medium", size: 11))
                            .foregroundStyle(KokoInk.secondary)
                            .lineLimit(2)
                        Text("Open the feed →")
                            .font(.custom("AvenirNext-Bold", size: 10))
                            .foregroundStyle(KokoInk.coral)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 15)
            }
            .frame(maxWidth: .infinity, minHeight: 112)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }.buttonStyle(KokoPressStyle()).accessibilityLabel("See all community updates")
    }
}

private struct KokoHostsStrip: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Meet the hosts").font(.custom("AvenirNext-Bold", size: 20))
                    Text("Find a room that feels like you").font(.custom("AvenirNext-Medium", size: 10)).foregroundStyle(KokoInk.secondary)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(community.members) { member in
                        Button { navigation.open(.profile(member.id)) } label: {
                            VStack(alignment: .leading, spacing: 7) {
                                KokoMemberPortrait(member: member)
                                    .frame(width: 112, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                Text(member.publicName.components(separatedBy: " ").first ?? member.publicName).font(.custom("AvenirNext-Bold", size: 13)).lineLimit(1)
                                Text("Open to chat →").font(.custom("AvenirNext-Medium", size: 10)).foregroundStyle(KokoInk.coral)
                            }.frame(width: 112, alignment: .leading)
                        }.buttonStyle(KokoPressStyle()).accessibilityLabel("Meet \(member.publicName)")
                    }
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct KokoDiscoverActionCards: View {
    @EnvironmentObject private var navigation: KokoSceneNavigation
    var body: some View {
        HStack(spacing: 12) {
            actionCard(title: "Photos & videos", detail: "Keep the good bits") { navigation.open(.momentsCollection) }
            actionCard(title: "Find your people", detail: "Search the community") { navigation.open(.search) }
        }
    }
    private func actionCard(title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack(alignment: .leading) {
                Image("KokoSocialWidePanelShell")
                    .resizable()
                    .scaledToFill()
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 9) {
                    Text(title)
                        .font(.custom("AvenirNext-Bold", size: 14))
                        .lineLimit(2)
                    Text(detail)
                        .font(.custom("AvenirNext-Medium", size: 10))
                        .foregroundStyle(KokoInk.secondary)
                        .lineLimit(2)
                    Text("Explore →")
                        .font(.custom("AvenirNext-Bold", size: 10))
                        .foregroundStyle(KokoInk.coral)
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity, minHeight: 132)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }.buttonStyle(KokoPressStyle())
    }
}

/// Uses the host's supplied photograph, never a film thumbnail presented as a live stream.
struct KokoRoomHostCover: View {
    @EnvironmentObject private var community: CommunityJournalStore
    let room: ListeningRoom
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
                Text(room.isVideoStage ? "LIVE ROOM" : "VOICE ROOM").tracking(1)
                Text("/ PREVIEW").foregroundStyle(KokoInk.secondary)
            }
            .font(.custom("AvenirNext-Bold", size: 10))
            .foregroundStyle(KokoInk.primary)
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(KokoControlSurface()).padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityLabel(room.isVideoStage ? "Live room preview cover. No broadcast is connected." : "Voice room preview cover. No audio is broadcast.")
    }
}

private struct KokoLiveDirectoryHero: View {
    let roomCount: Int
    let create: () -> Void
    var body: some View {
        ZStack(alignment: .leading) {
            Image("KokoHomeHeroArtwork")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, minHeight: 154, maxHeight: 154)
                .clipped()
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("ON AIR")
                            .font(.custom("AvenirNext-Bold", size: 11))
                            .tracking(1.2)
                            .foregroundStyle(KokoInk.coral)
                        Text("\(roomCount) rooms open")
                            .font(.custom("AvenirNext-Medium", size: 10))
                            .foregroundStyle(KokoInk.secondary)
                    }
                    Text("Find your people in the moment")
                        .font(.custom("AvenirNext-Bold", size: 21, relativeTo: .title2))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Watch, react, and join the room that fits your mood.")
                        .font(.custom("AvenirNext-Medium", size: 11))
                        .foregroundStyle(KokoInk.secondary)
                        .lineLimit(2)
                    Button(action: create) {
                        Text("Go live")
                        .font(.custom("AvenirNext-Bold", size: 11))
                        .foregroundStyle(KokoInk.onMint)
                        .padding(.horizontal, 16)
                        .frame(height: 34)
                        .background {
                            Image("KokoHomeHeroButton")
                                .resizable()
                                .scaledToFill()
                        }
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 154, maxHeight: 154, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("On air now. \(roomCount) live rooms.")
    }
}

private struct KokoDiscoverCategoryRail: View {
    @Binding var selection: String
    let select: (String) -> Void
    private let categories: [(String, Int)] = [
        ("For you", 0), ("Following", 1), ("Conversation", 2), ("Music", 3), ("Creative", 4), ("After hours", 5)
    ]
    var body: some View {
        ZStack {
            Image("KokoHomeCategoryRail")
                .resizable()
                .scaledToFit()
                .accessibilityHidden(true)
            HStack(spacing: 4) {
                ForEach(categories, id: \.0) { category, _ in
                    Button { select(category) } label: {
                        Text(category)
                            .font(.custom("AvenirNext-DemiBold", size: 10, relativeTo: .caption))
                            .minimumScaleFactor(0.72)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .foregroundStyle(selection == category ? KokoInk.onMint : KokoInk.primary)
                    }
                    .buttonStyle(KokoPressStyle())
                    .accessibilityAddTraits(selection == category ? .isSelected : [])
                }
            }
            .padding(.horizontal, 7)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(3, contentMode: .fit)
    }
}

private struct KokoLiveSectionHeading: View {
    let category: String
    var body: some View {
        HStack(spacing: 11) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Live rooms").font(.custom("AvenirNext-Bold", size: 20, relativeTo: .title3))
                Text(category == "For you" ? "A room for your mood" : "\(category) rooms")
                    .font(.custom("AvenirNext-Medium", size: 10)).foregroundStyle(KokoInk.secondary)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct KokoLiveRoomCard: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    let room: ListeningRoom
    private var host: CommunityMember? { community.member(room.hostMemberID) }
    var body: some View {
        Button { navigation.open(.room(room.id)) } label: {
            ZStack(alignment: .topLeading) {
                Image("KokoHomeLiveCardShell")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    ZStack(alignment: .bottomLeading) {
                        if let preview = KokoMediaLibrary.liveRoomPreview(for: room.id) {
                            KokoContentImage(asset: preview)
                                .frame(maxWidth: .infinity)
                                .frame(height: 116)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        } else if let host {
                            KokoMemberCoverPhoto(member: host)
                                .frame(maxWidth: .infinity)
                                .frame(height: 116)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        } else {
                            KokoPhotoPlaceholder()
                                .frame(maxWidth: .infinity)
                                .frame(height: 116)
                        }
                        HStack(spacing: 8) {
                            ZStack {
                                Image("KokoLiveNowBadge")
                                    .resizable()
                                    .scaledToFit()
                                Text("LIVE NOW")
                                    .font(.custom("AvenirNext-Bold", size: 7))
                                    .tracking(0.8)
                                    .foregroundStyle(KokoInk.primary)
                                    .padding(.leading, 19)
                            }
                            .frame(width: 92, height: 26)
                            Spacer(minLength: 0)
                            Text("\(room.seatAssignments.count) here")
                                .font(.custom("AvenirNext-Bold", size: 9))
                        }
                        .foregroundStyle(KokoInk.primary)
                        .padding(10)
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                    VStack(alignment: .leading, spacing: 7) {
                        Text(room.roomTitle)
                            .font(.custom("AvenirNext-Bold", size: 15))
                            .foregroundStyle(KokoInk.canvas)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                        Text(room.conversationPrompt)
                            .font(.custom("AvenirNext-Regular", size: 10))
                            .foregroundStyle(KokoInk.canvas.opacity(0.72))
                            .lineLimit(1)
                        if let host {
                            Text("Hosted by \(host.publicName) · talking now")
                                .font(.custom("AvenirNext-DemiBold", size: 9))
                                .foregroundStyle(KokoInk.canvas.opacity(0.78))
                                .lineLimit(1)
                        }
                        HStack(spacing: 7) {
                            Text(room.conversationTopic)
                                .font(.custom("AvenirNext-Bold", size: 8))
                                .tracking(0.8)
                                .foregroundStyle(KokoInk.coral)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Spacer(minLength: 0)
                            Text("Join chat →")
                                .font(.custom("AvenirNext-Bold", size: 9))
                                .foregroundStyle(KokoInk.coral)
                        }
                    }
                    .padding(.horizontal, 13)
                    .padding(.top, 12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(0.67, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
        }.frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .buttonStyle(KokoPressStyle())
            .accessibilityLabel("Join live room hosted by \(host?.publicName ?? "Koko")")
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
                KokoModal(title: "Collection filters", dismiss: { choosingFilters = false }) {
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
                Text("Community updates").font(.custom("AvenirNext-Bold", size: 20, relativeTo: .title3))
                Text("\(videoCount) videos · photos from your people").font(.custom("AvenirNext-Medium", size: 10)).foregroundStyle(KokoInk.secondary)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct KokoMomentCard: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    let moment: SharedMoment
    var body: some View {
        Button { navigation.open(.moment(moment.id)) } label: {
            ZStack(alignment: .topLeading) {
                Image("KokoHomeMomentCardShell")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    Group {
                        if let asset = moment.mediaAsset {
                            KokoContentImage(asset: asset)
                                .frame(maxWidth: .infinity)
                                .frame(height: 122)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        } else {
                            Artwork(sheet: .collection, tile: moment.coverTile)
                                .frame(maxWidth: .infinity)
                                .frame(height: 122)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                    if let asset = moment.mediaAsset {
                        Text(asset.isVideo ? "VIDEO · \(asset.durationLabel)" : "PHOTO")
                            .font(.custom("AvenirNext-Bold", size: 8))
                            .tracking(1)
                            .foregroundStyle(KokoInk.coral)
                            .padding(.horizontal, 13)
                            .padding(.top, 10)
                    }
                    VStack(alignment: .leading, spacing: 7) {
                        Text(moment.topicLabel.uppercased())
                            .font(.custom("AvenirNext-Bold", size: 8))
                            .tracking(1)
                            .foregroundStyle(KokoInk.coral)
                        Text(moment.captionLine)
                            .font(.custom("AvenirNext-Bold", size: 14, relativeTo: .body))
                            .foregroundStyle(KokoInk.primary)
                            .lineLimit(2)
                        HStack(spacing: 5) {
                            Text(community.member(moment.creatorMemberID)?.publicName ?? "Koko")
                                .font(.custom("AvenirNext-DemiBold", size: 10))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Text("Open moment →")
                                .font(.custom("AvenirNext-Bold", size: 9))
                                .foregroundStyle(KokoInk.coral)
                        }
                    }
                    .padding(.horizontal, 13)
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .foregroundStyle(KokoInk.primary)
            .frame(maxWidth: .infinity)
            .aspectRatio(0.67, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }.buttonStyle(KokoPressStyle()).accessibilityLabel(moment.mediaAsset?.isVideo == true ? "Open video update" : "Open photo update")
    }
}

struct KokoRoomCard: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    let room: ListeningRoom
    var body: some View {
        Button { navigation.open(.room(room.id)) } label: {
            HStack(alignment: .center, spacing: 15) {
                if let host = community.member(room.hostMemberID) {
                    KokoMemberPortrait(member: host).frame(width: 88, height: 104)
                } else { KokoPhotoPlaceholder().frame(width: 88, height: 104) }
                VStack(alignment: .leading, spacing: 6) {
                    Text(room.conversationTopic.uppercased()).font(.custom("AvenirNext-DemiBold", size: 10)).tracking(1).foregroundStyle(KokoInk.accent)
                    Text(room.roomTitle).font(.custom("AvenirNext-Bold", size: 17, relativeTo: .headline)).fixedSize(horizontal: false, vertical: true)
                    Text(room.conversationPrompt).font(.custom("AvenirNext-Regular", size: 12)).foregroundStyle(KokoInk.secondary).lineLimit(2)
                    Text("\(room.seatAssignments.count)/\(room.seatLimit) seats · \(room.isVideoStage ? "Video" : "Voice") preview").font(.custom("AvenirNext-Medium", size: 10))
                }
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
    private var rooms: [ListeningRoom] { community.rooms.filter { room in matches(room.roomTitle + " " + room.conversationPrompt) && (topic == "All" || room.conversationTopic == topic) && community.member(room.hostMemberID).map(accepts) == true } }
    private var moments: [SharedMoment] { community.moments.filter { moment in matches(moment.captionLine) && (topic == "All" || moment.topicLabel == topic) && community.member(moment.creatorMemberID).map(accepts) == true } }
    var body: some View {
        ZStack {
            KokoPage(title: "Find your people", subtitle: "Follow a curiosity.", back: navigation.back) {
                HStack { KokoSearchField(prompt: "People, rooms, moments", query: $searchWords); KokoIconAction(icon: 11, label: "Filters") { filtersVisible = true } }
                KokoChoiceRail(choices: ["All", "People", "Rooms", "Moments"], selection: $resultKind)
                KokoChoiceRail(choices: KokoCommunity.topics, selection: $topic)
                if resultKind == "All" || resultKind == "People" {
                    Text("People · \(people.count)").font(.custom("AvenirNext-Bold", size: 19))
                    ForEach(people) { member in KokoMemberRow(member: member) }
                }
                if resultKind == "All" || resultKind == "Rooms" {
                    Text("Rooms · \(rooms.count)").font(.custom("AvenirNext-Bold", size: 19))
                    ForEach(rooms) { room in KokoRoomCard(room: room) }
                }
                if resultKind == "All" || resultKind == "Moments" {
                    Text("Moments · \(moments.count)").font(.custom("AvenirNext-Bold", size: 19))
                    ForEach(moments) { moment in KokoMomentCard(moment: moment) }
                }
                if (resultKind == "People" && people.isEmpty) || (resultKind == "Rooms" && rooms.isEmpty) || (resultKind == "Moments" && moments.isEmpty) || (people.isEmpty && rooms.isEmpty && moments.isEmpty) {
                    KokoEmpty(title: "No matches just yet", detail: "Try another word or widen your filters.")
                }
            }
            if filtersVisible {
                KokoModal(title: "Make it your kind", dismiss: { filtersVisible = false }) {
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
                VStack(alignment: .leading, spacing: 5) { Text(member.publicName).font(.custom("AvenirNext-DemiBold", size: 17)); Text("\(member.hometownLabel) · \(member.spokenLanguage)").font(.custom("AvenirNext-Regular", size: 12)).foregroundStyle(KokoInk.secondary) }
                Spacer()
            }.padding(14).background(ArtworkSurface())
        }.buttonStyle(KokoPressStyle())
    }
}

struct KokoSafetyPanel: View {
    @EnvironmentObject private var community: CommunityJournalStore
    let subjectKey: String
    let memberID: String
    let dismiss: () -> Void
    @State private var reason = "Harassment"
    @State private var confirmBlock = false
    var body: some View {
        KokoModal(title: confirmBlock ? "Block this person?" : "Keep your space comfortable", dismiss: dismiss) {
            if confirmBlock {
                Text("Their rooms, moments and conversations will be hidden on this device. You can undo this in your blocked list.")
                KokoAction(title: "Block person") { community.block(memberID); dismiss() }
                KokoAction(title: "Go back", emphasis: false) { confirmBlock = false }
            } else {
                ForEach(["Harassment", "Hateful content", "Sexual content", "Violence", "Spam or scam", "Privacy concern", "Other"], id: \.self) { option in
                    KokoToggleRow(title: option, enabled: Binding(get: { reason == option }, set: { _ in reason = option }))
                }
                KokoAction(title: "Save report & hide") { community.report(subjectKey, reason: reason); dismiss() }
                if memberID != community.myID { KokoAction(title: "Block this person", emphasis: false) { confirmBlock = true } }
            }
        }
    }
}
