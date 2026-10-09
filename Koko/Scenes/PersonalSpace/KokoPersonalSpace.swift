import SwiftUI

struct KokoPersonalSpace: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @State private var confirmLogout = false
    var body: some View {
        ZStack {
            KokoPage {
                KokoSocialHero(
                    eyebrow: "Your corner of Koko",
                    title: "A little more you",
                    detail: "Keep the people, rooms, and little moments that feel like yours close by.",
                    artwork: 3
                )
                if let member = community.currentMember {
                    KokoCard {
                        HStack(alignment: .top, spacing: 16) {
                            KokoMemberPortrait(member: member).frame(width: 76, height: 86)
                            VStack(alignment: .leading, spacing: 8) {
                                Text(member.publicName).font(.custom("AvenirNext-Bold", size: 22, relativeTo: .title2)).fixedSize(horizontal: false, vertical: true)
                                if !member.hometownLabel.isEmpty { Text(member.hometownLabel).font(.custom("AvenirNext-Regular", size: 12)).foregroundStyle(KokoInk.secondary) }
                                Text(member.introductionLine.isEmpty ? "Add a little about yourself." : member.introductionLine).font(.custom("AvenirNext-Regular", size: 13)).foregroundStyle(KokoInk.secondary).lineLimit(3)
                                KokoAction(title: "Edit profile", emphasis: false) { navigation.open(.editProfile) }.frame(maxWidth: 150)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if let worn = KokoCommunity.keepsakes.first(where: { $0.id == community.journal?.wornKeepsakeID }) {
                            HStack { Artwork(sheet: .collection, tile: worn.artworkTile).frame(width: 30, height: 30); Text(worn.keepsakeName).font(.custom("AvenirNext-DemiBold", size: 12)) }
                        }
                    }
                }
                HStack(spacing: 8) {
                    relationship("Followers", community.followers.count)
                    relationship("Following", community.following.count)
                    relationship("Friends", community.friends.count)
                }.padding(.vertical, 14).background(ArtworkSurface())
                KokoCard(tint: 3) {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 6) { Artwork(sheet: .navigation, tile: 9).frame(width: 20, height: 20); Text("Your balance").font(.custom("AvenirNext-Medium", size: 12)) }.foregroundStyle(KokoInk.accent)
                            Text("\(community.coinBalance)").font(.custom("AvenirNext-Bold", size: 32, relativeTo: .largeTitle))
                            Text("coins").font(.custom("AvenirNext-Regular", size: 12)).foregroundStyle(KokoInk.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        KokoAction(title: "Top up", icon: 7) { navigation.open(.wallet) }.frame(width: 124)
                    }
                }
                KokoMenuRow(title: community.checkedInToday ? "Checked in today" : "Your daily check-in", detail: "Level \(community.activityLevel) · \(community.activityPoints % 200)/200 points", icon: 15) { navigation.open(.checkIn) }
                HStack(spacing: 10) {
                    KokoAction(title: "Album", icon: 3, emphasis: false) { navigation.open(.album) }
                    KokoAction(title: "Saved", icon: 8, emphasis: false) { navigation.open(.savedMoments) }
                }
                KokoSectionTitle(title: "Collected by you")
                KokoMenuRow(title: "Keepsake shop", detail: "Gifts & little extras", icon: 8) { navigation.open(.shop) }
                KokoMenuRow(title: "Backpack", detail: "Your keepsakes", icon: 9) { navigation.open(.backpack) }
                KokoMenuRow(title: "Your level", icon: 15) { navigation.open(.level) }
                KokoSectionTitle(title: "Make it yours")
                KokoMenuRow(title: "Feedback", icon: 2) { navigation.open(.feedback) }
                KokoMenuRow(title: "Blocked people", icon: 14) { navigation.open(.blacklist) }
                KokoMenuRow(title: "Settings", icon: 11) { navigation.open(.settings) }
                KokoAction(title: "Sign out", emphasis: false) { confirmLogout = true }
                LocalPreviewNote()
            }
            if confirmLogout { KokoModal(title: "Until next time?", dismiss: { confirmLogout = false }) { Text("Your local profile and keepsakes will be here when you sign in with the same email."); KokoAction(title: "Sign out") { community.signOut() } } }
        }
    }
    private func relationship(_ title: String, _ count: Int) -> some View {
        Button { navigation.open(.friends(title)) } label: {
            VStack(spacing: 5) { Text("\(count)").font(.custom("AvenirNext-Bold", size: 24)); Text(title).font(.custom("AvenirNext-Medium", size: 11)).foregroundStyle(KokoInk.secondary) }.frame(maxWidth: .infinity, minHeight: 50).contentShape(Rectangle())
        }.buttonStyle(KokoPressStyle())
    }
}

struct KokoMemberProfile: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    let memberID: String
    @State private var safety = false
    @State private var showSample = false
    private var visibleMoments: [SharedMoment] { community.moments.filter { $0.creatorMemberID == memberID } }
    private var visibleRooms: [ListeningRoom] { community.rooms.filter { $0.hostMemberID == memberID } }
    var body: some View {
        ZStack {
            KokoPage(title: "Meet someone", subtitle: "A profile with room to connect.", back: navigation.back) {
                if let member = community.member(memberID) {
                    profileHero(member)
                    profileStats(member)
                    if !member.introductionLine.isEmpty {
                        KokoCard(tint: 3) {
                            HStack(alignment: .top, spacing: 12) {
                                Artwork(sheet: .social, tile: 2).frame(width: 62, height: 52)
                                Text(member.introductionLine)
                                    .font(.custom("AvenirNext-Medium", size: 18, relativeTo: .body))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    if !member.interests.isEmpty {
                        KokoSectionTitle(title: "What they are into", detail: "A few shared threads")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(member.interests, id: \.self) { interest in KokoSocialTag(title: interest) }
                            }
                        }
                    }
                    if memberID != community.myID {
                        HStack(spacing: 10) {
                            KokoAction(title: community.following.contains(memberID) ? "Following" : "Follow", icon: 7) { community.toggleFollow(memberID) }
                            KokoIconAction(icon: 11, label: "Report or block") { safety = true }
                        }
                        KokoAction(title: "Send a hello", icon: 2, emphasis: false) { navigation.open(.conversation(memberID)) }
                        KokoCard(tint: 3) {
                            HStack(alignment: .top, spacing: 12) {
                                Artwork(sheet: .social, tile: 0).frame(width: 68, height: 58)
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Make a moment together").font(.custom("AvenirNext-Bold", size: 18))
                                    Text("Voice and video are free when the connection is mutual.")
                                        .font(.custom("AvenirNext-Regular", size: 13)).foregroundStyle(KokoInk.secondary)
                                    HStack(spacing: 10) {
                                        KokoAction(title: "Voice", icon: 13, emphasis: false) { navigation.open(.call(memberID, .voice)) }
                                        KokoAction(title: "Video", icon: 0, emphasis: false) { navigation.open(.call(memberID, .video)) }
                                    }
                                }
                            }
                        }
                        KokoCard {
                            HStack(alignment: .top, spacing: 12) {
                                Artwork(sheet: .social, tile: 1).frame(width: 58, height: 48)
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("A little context").font(.custom("AvenirNext-Bold", size: 18))
                                    LocalPreviewNote(text: "SAMPLE PROFILE")
                                    Text(community.friends.contains(memberID) ? "You have a local sample mutual connection." : "This profile is a local preview on your device.").font(.custom("AvenirNext-Regular", size: 13))
                                    if !community.friends.contains(memberID) { KokoAction(title: "Try a sample mutual connection", emphasis: false) { showSample = true } }
                                }
                            }
                        }
                    }
                    KokoSectionTitle(title: "From their world", detail: "Shared moments and rooms")
                    ForEach(visibleMoments) { KokoMomentCard(moment: $0) }
                    ForEach(visibleRooms) { KokoRoomCard(room: $0) }
                } else { KokoEmpty(title: "Profile not found", detail: "This profile is no longer available here.") }
            }
            if safety { KokoSafetyPanel(subjectKey: memberID, memberID: memberID) { safety = false; if community.journal?.blockedMembers.contains(memberID) == true { navigation.back() } } }
            if showSample { KokoModal(title: "Try a sample friendship?", dismiss: { showSample = false }) { Text("This adds a mutual connection only on your device. It does not mean a real person followed you."); KokoAction(title: "Add sample connection") { community.enableSampleFriendship(memberID); showSample = false } } }
        }
    }
    private func profileHero(_ member: CommunityMember) -> some View {
        ZStack(alignment: .bottomLeading) {
            KokoMemberCoverPhoto(member: member)
                .frame(height: 306)
            LinearGradient(
                colors: [Color.clear, KokoInk.canvas.opacity(0.12), KokoInk.canvas.opacity(0.96)],
                startPoint: .top,
                endPoint: .bottom
            )
            Artwork(sheet: .social, tile: 2)
                .frame(width: 106, height: 80)
                .opacity(0.22)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(14)
            HStack(alignment: .bottom, spacing: 12) {
                KokoMemberPortrait(member: member)
                    .frame(width: 86, height: 94)
                    .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(KokoInk.paper.opacity(0.9), lineWidth: 2) }
                VStack(alignment: .leading, spacing: 5) {
                    Text(member.publicName).font(.custom("AvenirNext-Bold", size: 30, relativeTo: .title2))
                    Text("\(member.adultAge) · \(member.hometownLabel) · \(member.spokenLanguage)")
                        .font(.custom("AvenirNext-Medium", size: 12, relativeTo: .caption))
                        .foregroundStyle(KokoInk.paper.opacity(0.78))
                }
                Spacer(minLength: 0)
            }
            .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(KokoInk.accent.opacity(0.44), lineWidth: 1) }
        .shadow(color: Color.black.opacity(0.24), radius: 16, y: 8)
    }
    private func profileStats(_ member: CommunityMember) -> some View {
        KokoCard(tint: 5) {
            HStack(spacing: 0) {
                profileStat("Rooms", visibleRooms.count)
                profileStat("Moments", visibleMoments.count)
                profileStat("Connection", community.friends.contains(member.id) ? "Mutual" : "Open")
            }
        }
    }
    private func profileStat(_ title: String, _ value: some CustomStringConvertible) -> some View {
        VStack(spacing: 5) {
            Text(value.description).font(.custom("AvenirNext-Bold", size: 18, relativeTo: .headline))
            Text(title).font(.custom("AvenirNext-Medium", size: 10, relativeTo: .caption2)).foregroundStyle(KokoInk.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
    }
}

struct KokoConnectionsView: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    let kind: String
    @State private var query = ""
    private var members: [CommunityMember] {
        let ids = kind == "Friends" ? community.friends : (kind == "Followers" ? community.followers : community.following)
        return community.members.filter { ids.contains($0.id) && (query.isEmpty || $0.publicName.localizedCaseInsensitiveContains(query)) }
    }
    var body: some View {
        KokoPage(title: kind, back: navigation.back) {
            KokoField(label: "Search people", value: $query)
            ForEach(members) { member in
                VStack(spacing: 8) {
                    KokoMemberRow(member: member)
                    if kind == "Friends" {
                        HStack {
                            KokoAction(title: "Voice call", icon: 13, emphasis: false) { navigation.open(.call(member.id, .voice)) }
                            KokoAction(title: "Video call", icon: 0, emphasis: false) { navigation.open(.call(member.id, .video)) }
                        }
                    }
                }
            }
            if members.isEmpty { KokoEmpty(title: "Good company takes a first hello", detail: "Find a creator in Discover. Sample mutual connections can be enabled from their profile."); KokoAction(title: "Explore people", icon: 4) { navigation.open(.search) } }
            LocalPreviewNote()
        }
    }
}

struct KokoAlbumView: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @State private var picker = false
    @State private var selectedPhotoKey: String?
    @State private var viewingPhotoKey: String?
    @State private var viewingLegacyIndex: Int?
    @State private var deletionConfirmation = false
    private var albumPhotos: [CommunityMediaAsset] {
        (community.journal?.albumPhotoKeys ?? []).compactMap { KokoMediaLibrary.asset($0) }
    }
    var body: some View {
        ZStack {
            KokoPage(title: "Pieces of your world", subtitle: "Your personal album", back: navigation.back) {
                KokoAction(title: "Add from the collection", icon: 7) { selectedPhotoKey = nil; picker = true }
                let tiles = community.journal?.albumTiles ?? []
                if albumPhotos.isEmpty && tiles.isEmpty {
                    KokoEmpty(title: "A little room for memories", detail: "Choose a photograph from the collection and keep it in your album on this device.", art: 3)
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
                    ForEach(albumPhotos) { photo in
                        Button { viewingPhotoKey = photo.id; deletionConfirmation = false } label: {
                            KokoContentImage(asset: photo).frame(height: 190).padding(8).background(ArtworkSurface())
                        }.buttonStyle(KokoPressStyle()).accessibilityLabel("Open " + photo.captionLine)
                    }
                    // Keep earlier local artwork selections readable after the media-library upgrade.
                    ForEach(Array(tiles.enumerated()), id: \.offset) { index, tile in
                        Button { viewingLegacyIndex = index; deletionConfirmation = false } label: {
                            Artwork(sheet: .collection, tile: tile).frame(height: 170).padding(8).background(ArtworkSurface())
                        }.buttonStyle(.plain).accessibilityLabel("Open saved illustration \(index + 1)")
                    }
                }
            }
            if picker {
                KokoModal(title: "Choose a photograph", dismiss: { picker = false }) {
                    KokoCollectionPhotoPicker(selectedPhotoKey: $selectedPhotoKey)
                    KokoAction(title: "Add to album") {
                        guard let selectedPhotoKey, KokoMediaLibrary.asset(selectedPhotoKey)?.isVideo == false else { community.notice = "Choose a photo first."; return }
                        guard !(community.journal?.albumPhotoKeys ?? []).contains(selectedPhotoKey) else { community.notice = "This photo is already in your album."; return }
                        if community.update({ journal in
                            var keys = journal.albumPhotoKeys ?? []
                            keys.append(selectedPhotoKey); journal.albumPhotoKeys = keys
                        }) { picker = false; self.selectedPhotoKey = nil }
                    }
                }
            }
            if let photo = KokoMediaLibrary.asset(viewingPhotoKey) {
                KokoModal(title: "Your album", dismiss: { viewingPhotoKey = nil; deletionConfirmation = false }) {
                    KokoContentImage(asset: photo, fullResolution: true, fitInside: true).frame(height: 370)
                    Text(photo.captionLine).font(.custom("AvenirNext-DemiBold", size: 16))
                    if deletionConfirmation {
                        Text("Remove this photograph from your local album? It remains in the collection.")
                        KokoAction(title: "Remove photo") {
                            if community.update({ $0.albumPhotoKeys?.removeAll { $0 == photo.id } }) { viewingPhotoKey = nil; deletionConfirmation = false }
                        }
                    } else { KokoAction(title: "Remove from album", emphasis: false) { deletionConfirmation = true } }
                }
            }
            if let index = viewingLegacyIndex, let tiles = community.journal?.albumTiles, tiles.indices.contains(index) {
                KokoModal(title: "Saved illustration", dismiss: { viewingLegacyIndex = nil; deletionConfirmation = false }) {
                    Artwork(sheet: .collection, tile: tiles[index]).frame(height: 280)
                    if deletionConfirmation {
                        Text("Remove this illustration from your local album?")
                        KokoAction(title: "Remove illustration") {
                            if community.update({ $0.albumTiles.remove(at: index) }) { viewingLegacyIndex = nil; deletionConfirmation = false }
                        }
                    } else { KokoAction(title: "Remove from album", emphasis: false) { deletionConfirmation = true } }
                }
            }
        }
    }
}
