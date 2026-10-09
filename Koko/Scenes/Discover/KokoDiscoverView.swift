import SwiftUI

// Home is a video-room directory; recorded media has its own collection.
struct KokoDiscoverView: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @State private var roomAudience = "Live rooms"
    @State private var roomTopic = "All"
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

    private let roomColumns = [
        GridItem(.adaptive(minimum: 150, maximum: 260), spacing: 14, alignment: .top)
    ]

    var body: some View {
        ZStack {
            KokoPage {
                HStack(spacing: 10) {
                    KokoSearchField(prompt: "Search live rooms", query: $roomSearch)
                    KokoIconAction(icon: 0, label: "Create a live room") { navigation.open(.createRoom(true)) }
                }
                HStack(spacing: 10) {
                    KokoChoiceRail(choices: ["Live rooms", "Following"], selection: $roomAudience)
                    KokoIconAction(icon: 11, label: "Room topic: " + roomTopic) { choosingTopic = true }
                }
                if roomTopic != "All" {
                    HStack {
                        Text(roomTopic).font(.custom("AvenirNext-DemiBold", size: 12)).foregroundStyle(KokoInk.accent)
                        Spacer()
                        KokoIconAction(icon: 6, label: "Clear topic filter") { roomTopic = "All" }
                    }
                }
                KokoSectionTitle(title: "Live rooms", detail: "\(visibleRooms.count) previews")
                LazyVGrid(columns: roomColumns, spacing: 14) {
                    ForEach(visibleRooms) { room in KokoLiveRoomCard(room: room) }
                }
                if visibleRooms.isEmpty {
                    KokoEmpty(title: "No rooms here yet", detail: "Try another topic or create your own live room.", art: 1)
                    KokoAction(title: "Create a live room", icon: 0) { navigation.open(.createRoom(true)) }
                }
                LocalPreviewNote(text: "LOCAL ROOM PREVIEWS · NO LIVE BROADCAST IS CONNECTED")
                HStack {
                    KokoSectionTitle(title: "Community updates", detail: "Fresh from Koko")
                    Spacer(minLength: 0)
                }
                LazyVGrid(columns: roomColumns, spacing: 14) {
                    ForEach(Array(community.moments.prefix(4))) { moment in
                        KokoMomentCard(moment: moment)
                    }
                }
                KokoMenuRow(title: "See all updates", detail: "Photos and videos from the community", icon: 4) {
                    navigation.open(.momentsCollection)
                }
                HStack {
                    KokoSectionTitle(title: "Meet the hosts")
                    Spacer(minLength: 8)
                    KokoIconAction(icon: 15, label: "Community ranking") { navigation.open(.ranking) }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(community.members) { member in
                            Button { navigation.open(.profile(member.id)) } label: {
                                VStack(alignment: .leading, spacing: 9) {
                                    KokoMemberPortrait(member: member).frame(width: 104, height: 116)
                                    Text(member.publicName.components(separatedBy: " ").first ?? member.publicName)
                                        .font(.custom("AvenirNext-DemiBold", size: 14)).lineLimit(1)
                                }.frame(width: 104, alignment: .leading)
                            }.buttonStyle(KokoPressStyle()).accessibilityLabel("View " + member.publicName)
                        }
                    }
                }
                KokoMenuRow(title: "Photos & videos", detail: "Explore the collection", icon: 0) {
                    navigation.open(.momentsCollection)
                }
                KokoMenuRow(title: "Search the community", detail: "People, rooms and shared moments", icon: 4) {
                    navigation.open(.search)
                }
            }
            .allowsHitTesting(!choosingTopic)
            .accessibilityHidden(choosingTopic)
            if choosingTopic {
                KokoModal(title: "Room topics", dismiss: { choosingTopic = false }) {
                    ForEach(KokoCommunity.topics, id: \.self) { topic in
                        KokoAction(title: topic == "All" ? "All topics" : topic, emphasis: roomTopic == topic) {
                            roomTopic = topic
                            choosingTopic = false
                        }
                    }
                }
            }
        }
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

struct KokoLiveRoomCard: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    let room: ListeningRoom
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button { navigation.open(.room(room.id)) } label: {
                KokoRoomHostCover(room: room).frame(height: 148)
            }.buttonStyle(KokoPressStyle()).accessibilityLabel("Open live room preview: " + room.roomTitle)
            VStack(alignment: .leading, spacing: 9) {
                Text(room.roomTitle).font(.custom("AvenirNext-Bold", size: 16, relativeTo: .headline))
                    .fixedSize(horizontal: false, vertical: true)
                if let host = community.member(room.hostMemberID) {
                    Button { navigation.open(.profile(host.id)) } label: {
                        HStack(spacing: 7) {
                            KokoMemberPortrait(member: host).frame(width: 30, height: 30)
                            Text(host.publicName).font(.custom("AvenirNext-DemiBold", size: 11)).lineLimit(1)
                        }
                    }.buttonStyle(KokoPressStyle()).accessibilityLabel("View host " + host.publicName)
                }
                Text(room.conversationPrompt)
                    .font(.custom("AvenirNext-Regular", size: 11, relativeTo: .caption))
                    .foregroundStyle(KokoInk.secondary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    KokoSocialTag(title: room.conversationTopic)
                    Spacer(minLength: 0)
                    Text("Preview").font(.custom("AvenirNext-Medium", size: 10, relativeTo: .caption2)).foregroundStyle(KokoInk.secondary)
                }
            }
        }
        .padding(10)
        .foregroundStyle(KokoInk.primary)
        .background(ArtworkSurface(tile: room.isVideoStage ? 3 : 2))
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

struct KokoMomentCard: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    let moment: SharedMoment
    var body: some View {
        Button { navigation.open(.moment(moment.id)) } label: {
            VStack(alignment: .leading, spacing: 9) {
                if let asset = moment.mediaAsset {
                    KokoContentImage(asset: asset).frame(height: 180)
                    Text(asset.isVideo ? "FILM · " + asset.durationLabel : "PHOTO")
                        .font(.custom("AvenirNext-Bold", size: 9)).tracking(1).foregroundStyle(KokoInk.accent)
                } else { Artwork(sheet: .collection, tile: moment.coverTile).frame(height: 180) }
                Text(moment.topicLabel.uppercased()).font(.custom("AvenirNext-DemiBold", size: 9)).tracking(1).foregroundStyle(KokoInk.secondary)
                Text(moment.captionLine).font(.custom("AvenirNext-DemiBold", size: 15, relativeTo: .body)).lineLimit(3).fixedSize(horizontal: false, vertical: true)
                Text(community.member(moment.creatorMemberID)?.publicName ?? "Koko").font(.custom("AvenirNext-Regular", size: 11)).foregroundStyle(KokoInk.secondary).lineLimit(1)
            }.foregroundStyle(KokoInk.primary).padding(12).frame(maxWidth: .infinity, alignment: .leading).background(ArtworkSurface())
        }.buttonStyle(KokoPressStyle())
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
                KokoAction(title: "Save report & hide locally") { community.report(subjectKey, reason: reason); dismiss() }
                if memberID != community.myID { KokoAction(title: "Block this person", emphasis: false) { confirmBlock = true } }
                LocalPreviewNote(text: "REPORTS ARE STORED LOCALLY UNTIL A MODERATION SERVICE IS CONNECTED")
            }
        }
    }
}
