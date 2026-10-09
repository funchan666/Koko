import SwiftUI

struct KokoPersonalSpace: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @State private var confirmLogout = false
    var body: some View {
        ZStack {
            KokoPage {
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
    var body: some View {
        ZStack {
            KokoPage(title: "Profile", back: navigation.back) {
                if let member = community.member(memberID) {
                    KokoMemberCoverPhoto(member: member)
                        .frame(height: 330)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .bottom, spacing: 12) {
                            KokoMemberPortrait(member: member).frame(width: 78, height: 86)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(member.publicName).font(.custom("AvenirNext-Bold", size: 28, relativeTo: .title2))
                                Text("\(member.adultAge) · \(member.hometownLabel) · \(member.spokenLanguage)")
                                    .font(.custom("AvenirNext-Regular", size: 12)).foregroundStyle(KokoInk.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        if !member.introductionLine.isEmpty {
                            Text(member.introductionLine).font(.custom("AvenirNext-Medium", size: 18, relativeTo: .body))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(member.interests, id: \.self) { interest in
                                    Text(interest).font(.custom("AvenirNext-DemiBold", size: 12))
                                        .foregroundStyle(KokoInk.onMint)
                                        .padding(.horizontal, 14).padding(.vertical, 10)
                                        .background(KokoControlSurface(highlighted: true))
                                }
                            }
                        }
                    }.padding(18).background(ArtworkSurface())
                    if memberID != community.myID {
                        HStack(spacing: 10) {
                            KokoAction(title: community.following.contains(memberID) ? "Following" : "Follow", icon: 7) { community.toggleFollow(memberID) }
                            KokoIconAction(icon: 11, label: "Report or block") { safety = true }
                        }
                        KokoAction(title: "Send a hello", icon: 2, emphasis: false) { navigation.open(.conversation(memberID)) }
                        KokoCard(tint: 3) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Make a moment together").font(.custom("AvenirNext-Bold", size: 18))
                                Text("Voice and video previews are ready when you are.")
                                    .font(.custom("AvenirNext-Regular", size: 13)).foregroundStyle(KokoInk.secondary)
                                HStack(spacing: 10) {
                                    KokoAction(title: "Voice", icon: 13, emphasis: false) { navigation.open(.call(memberID, .voice)) }
                                    KokoAction(title: "Video", icon: 0, emphasis: false) { navigation.open(.call(memberID, .video)) }
                                }
                            }
                        }
                        KokoCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("A little context").font(.custom("AvenirNext-Bold", size: 18))
                                LocalPreviewNote(text: "SAMPLE PROFILE")
                                Text(community.friends.contains(memberID) ? "You have a local sample mutual connection." : "This profile is a local preview on your device.").font(.custom("AvenirNext-Regular", size: 13))
                                if !community.friends.contains(memberID) { KokoAction(title: "Try a sample mutual connection", emphasis: false) { showSample = true } }
                            }
                        }
                    }
                    KokoSectionTitle(title: "From their world", detail: "Shared moments and rooms")
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
