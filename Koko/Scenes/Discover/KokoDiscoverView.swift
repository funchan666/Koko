import SwiftUI

struct KokoDiscoverView: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @State private var topic = "All"
    @State private var feed = "For you"
    @State private var mediaFormat = "Everything"
    var visibleMoments: [SharedMoment] {
        community.moments.filter { (topic == "All" || $0.topicLabel == topic) && (feed == "For you" || community.following.contains($0.creatorMemberID)) && (mediaFormat == "Everything" || (mediaFormat == "Films" ? $0.mediaAsset?.isVideo == true : $0.mediaAsset?.isVideo == false)) }
    }
    var body: some View {
        KokoPage(title: "koko", subtitle: "A LITTLE COMPANY GOES A LONG WAY") {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Stay for\nthe conversation.").font(.custom("AvenirNext-Bold", size: 32, relativeTo: .largeTitle)).lineSpacing(-3)
                    Text("A voice. A story. A new perspective.").font(.custom("AvenirNext-Regular", size: 13)).foregroundStyle(KokoInk.secondary)
                }
                Spacer(minLength: 0)
                KokoIconAction(icon: 4, label: "Search") { navigation.open(.search) }
            }
            ZStack(alignment: .bottomLeading) {
                Artwork(sheet: .scenes, tile: 0).frame(maxWidth: .infinity).frame(height: 265).clipped()
                VStack(alignment: .leading, spacing: 8) {
                    Text("THE LISTENING CLUB").font(.custom("AvenirNext-Bold", size: 10)).tracking(1.5)
                    Text("Find your frequency.").font(.custom("AvenirNext-Bold", size: 23))
                    KokoAction(title: "Explore rooms", icon: 1) { navigation.selectedTab = 1 }.frame(maxWidth: 190)
                }.padding(18).background(ArtworkSurface()).padding(10)
            }
            HStack(spacing: 10) {
                KokoAction(title: "Host a video room", icon: 0, emphasis: false) { navigation.open(.createRoom(true)) }
                KokoIconAction(icon: 15, label: "Community ranking") { navigation.open(.ranking) }
            }
            HStack { Text("Good people, good company").font(.custom("AvenirNext-DemiBold", size: 18)); Spacer() }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(community.members) { member in
                        Button { navigation.open(.profile(member.id)) } label: {
                            VStack(alignment: .leading, spacing: 7) {
                                KokoMemberPortrait(member: member).frame(width: 82, height: 82)
                                Text(member.publicName.components(separatedBy: " ").first ?? member.publicName).font(.custom("AvenirNext-DemiBold", size: 13))
                                Text(member.interests.first ?? "Conversation").font(.custom("AvenirNext-Regular", size: 10)).foregroundStyle(KokoInk.secondary)
                            }
                        }.buttonStyle(KokoPressStyle())
                    }
                }
            }
            KokoChoiceRail(choices: ["For you", "Following"], selection: $feed)
            KokoChoiceRail(choices: KokoCommunity.topics, selection: $topic)
            KokoChoiceRail(choices: ["Everything", "Photos", "Films"], selection: $mediaFormat)
            Text("\(visibleMoments.count) moments to explore").font(.custom("AvenirNext-Regular", size: 12)).foregroundStyle(KokoInk.secondary)
            if visibleMoments.isEmpty { KokoEmpty(title: "Something good is coming", detail: "Follow a creator or choose another topic to see more moments.") }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(visibleMoments) { moment in KokoMomentCard(moment: moment) }
            }
            Text("Open the door").font(.custom("AvenirNext-Bold", size: 23))
            ForEach(community.rooms.filter { topic == "All" || $0.conversationTopic == topic }) { room in KokoRoomCard(room: room) }
            LocalPreviewNote(text: "CURATED MEDIA COLLECTION · PEOPLE & ROOMS ARE LOCAL PREVIEWS")
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
                Text(moment.captionLine).font(.custom("AvenirNext-DemiBold", size: 16)).lineLimit(2).frame(height: 44, alignment: .topLeading)
                Text("Collected by " + (community.member(moment.creatorMemberID)?.publicName ?? "Koko")).font(.custom("AvenirNext-Regular", size: 12))
            }.foregroundStyle(KokoInk.primary).padding(12).frame(maxWidth: .infinity, alignment: .leading).background(ArtworkSurface())
        }.buttonStyle(KokoPressStyle())
    }
}

struct KokoRoomCard: View {
    @EnvironmentObject private var navigation: KokoSceneNavigation
    let room: ListeningRoom
    var body: some View {
        Button { navigation.open(.room(room.id)) } label: {
            HStack(alignment: .center, spacing: 15) {
                Artwork(sheet: .scenes, tile: room.artworkTile).frame(width: 90, height: 100)
                VStack(alignment: .leading, spacing: 6) {
                    Text(room.conversationTopic.uppercased()).font(.custom("AvenirNext-DemiBold", size: 10)).tracking(1).foregroundStyle(KokoInk.accent)
                    Text(room.roomTitle).font(.custom("AvenirNext-Bold", size: 19))
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
                HStack { KokoField(label: "People, rooms, moments", value: $searchWords); KokoIconAction(icon: 11, label: "Filters") { filtersVisible = true } }
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
