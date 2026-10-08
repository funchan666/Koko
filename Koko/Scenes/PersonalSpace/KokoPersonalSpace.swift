import SwiftUI

struct KokoPersonalSpace: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @State private var confirmLogout = false
    var body: some View {
        ZStack {
            KokoPage(title: "Make yourself at home", subtitle: "YOUR LITTLE CORNER OF KOKO") {
                if let member = community.currentMember {
                    HStack(alignment: .top, spacing: 18) {
                        KokoMemberPortrait(member: member).frame(width: 112, height: 125)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(member.publicName).font(.custom("AvenirNext-Bold", size: 27))
                            Text(member.hometownLabel.isEmpty ? "Somewhere good" : member.hometownLabel).font(.custom("AvenirNext-Regular", size: 13)).foregroundStyle(KokoInk.secondary)
                            Text(member.introductionLine.isEmpty ? "Make a little space for the things you love." : member.introductionLine).font(.custom("AvenirNext-Regular", size: 13))
                            Button("Edit your story") { navigation.open(.editProfile) }.font(.custom("AvenirNext-DemiBold", size: 12)).buttonStyle(.plain)
                        }
                        Spacer(minLength: 0)
                    }
                    if let worn = KokoCommunity.keepsakes.first(where: { $0.id == community.journal?.wornKeepsakeID }) {
                        HStack { Artwork(sheet: .collection, tile: worn.artworkTile).frame(width: 35, height: 35); Text(worn.keepsakeName).font(.custom("AvenirNext-DemiBold", size: 13)) }
                    }
                }
                HStack(spacing: 8) {
                    relationship("Followers", community.followers.count)
                    relationship("Following", community.following.count)
                    relationship("Friends", community.friends.count)
                }
                KokoCard(tint: 3) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("A small daily ritual.").font(.custom("AvenirNext-Bold", size: 22))
                            Text("Level \(community.activityLevel) · \(community.activityPoints % 200)/200 points").font(.custom("AvenirNext-Medium", size: 12))
                            Button(community.checkedInToday ? "Today's visit is saved" : "Check in for today") { navigation.open(.checkIn) }.font(.custom("AvenirNext-Bold", size: 13)).buttonStyle(.plain).padding(.vertical, 8)
                        }
                        Spacer()
                        Artwork(sheet: .collection, tile: 13).frame(width: 80, height: 90)
                    }
                }
                KokoMenuRow(title: "Your wallet", detail: "\(community.coinBalance) coins", icon: 9) { navigation.open(.wallet) }
                HStack(spacing: 10) {
                    KokoAction(title: "Album", icon: 3, emphasis: false) { navigation.open(.album) }
                    KokoAction(title: "Saved", icon: 8, emphasis: false) { navigation.open(.savedMoments) }
                }
                KokoMenuRow(title: "The little shop", detail: "Find something that feels like you", icon: 8) { navigation.open(.shop) }
                KokoMenuRow(title: "Your backpack", detail: "Small keepsakes, good memories", icon: 9) { navigation.open(.backpack) }
                KokoMenuRow(title: "Your level", icon: 15) { navigation.open(.level) }
                KokoMenuRow(title: "Leave us a note", icon: 2) { navigation.open(.feedback) }
                KokoMenuRow(title: "Blocked people", icon: 3) { navigation.open(.blacklist) }
                KokoMenuRow(title: "Settings", icon: 11) { navigation.open(.settings) }
                KokoAction(title: "Sign out", emphasis: false) { confirmLogout = true }
                LocalPreviewNote()
            }
            if confirmLogout { KokoModal(title: "Until next time?", dismiss: { confirmLogout = false }) { Text("Your local profile and keepsakes will be here when you sign in with the same email."); KokoAction(title: "Sign out") { community.signOut() } } }
        }
    }
    private func relationship(_ title: String, _ count: Int) -> some View {
        Button { navigation.open(.friends(title)) } label: {
            VStack(spacing: 5) { Text("\(count)").font(.custom("AvenirNext-Bold", size: 27)); Text(title).font(.custom("AvenirNext-Medium", size: 11)) }.frame(maxWidth: .infinity).padding(.vertical, 15).background(ArtworkSurface())
        }.buttonStyle(KokoPressStyle())
    }
}

struct KokoMemberProfile: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    let memberID: String
    @State private var safety = false
    @State private var showSample = false
    var body: some View {
        ZStack {
            KokoPage(title: "Meet someone", back: navigation.back) {
                if let member = community.member(memberID) {
                    KokoMemberPortrait(member: member).frame(height: 235)
                    Text(member.publicName).font(.custom("AvenirNext-Bold", size: 34))
                    Text("\(member.adultAge) · \(member.hometownLabel) · \(member.spokenLanguage)").foregroundStyle(KokoInk.secondary)
                    Text(member.introductionLine).font(.custom("AvenirNext-Medium", size: 19))
                    Text(member.interests.joined(separator: "  /  ")).font(.custom("AvenirNext-DemiBold", size: 12)).foregroundStyle(KokoInk.accent)
                    if memberID != community.myID {
                        HStack {
                            KokoAction(title: community.following.contains(memberID) ? "Following" : "Follow", icon: 7) { community.toggleFollow(memberID) }
                            KokoIconAction(icon: 11, label: "Report or block") { safety = true }
                        }
                        KokoAction(title: "Message", icon: 2, emphasis: false) { navigation.open(.conversation(memberID)) }
                        HStack {
                            KokoAction(title: "Voice call", icon: 13, emphasis: false) { navigation.open(.call(memberID, .voice)) }
                            KokoAction(title: "Video call", icon: 0, emphasis: false) { navigation.open(.call(memberID, .video)) }
                        }
                        KokoCard {
                            VStack(alignment: .leading, spacing: 10) {
                                LocalPreviewNote(text: "SAMPLE PROFILE")
                                Text(community.friends.contains(memberID) ? "You have a local sample mutual connection." : "Try the full friendship flow without contacting a real person.").font(.custom("AvenirNext-Regular", size: 13))
                                if !community.friends.contains(memberID) { KokoAction(title: "Try a sample mutual connection", emphasis: false) { showSample = true } }
                            }
                        }
                    }
                    Text("A little of their world").font(.custom("AvenirNext-Bold", size: 22))
                    ForEach(community.moments.filter { $0.creatorMemberID == memberID }) { KokoMomentCard(moment: $0) }
                    ForEach(community.rooms.filter { $0.hostMemberID == memberID }) { KokoRoomCard(room: $0) }
                } else { KokoEmpty(title: "Profile not found", detail: "This profile is no longer available here.") }
            }
            if safety { KokoSafetyPanel(subjectKey: memberID, memberID: memberID) { safety = false; if community.journal?.blockedMembers.contains(memberID) == true { navigation.back() } } }
            if showSample { KokoModal(title: "Try a sample friendship?", dismiss: { showSample = false }) { Text("This adds a mutual connection only on your device. It does not mean a real person followed you."); KokoAction(title: "Add sample connection") { community.enableSampleFriendship(memberID); showSample = false } } }
        }
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
