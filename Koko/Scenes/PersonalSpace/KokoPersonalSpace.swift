import SwiftUI

struct KokoPersonalSpace: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @State private var confirmLogout = false
    var body: some View {
        ZStack {
            KokoPage {
                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Your space")
                            .font(.custom("AvenirNext-Bold", size: 28, relativeTo: .title2))
                        Text("Keep the people and moments that feel like you close.")
                            .font(.custom("AvenirNext-Medium", size: 11, relativeTo: .caption))
                            .foregroundStyle(KokoInk.secondary)
                    }
                    Spacer(minLength: 0)
                    Text("KOKO")
                        .font(.custom("AvenirNext-Bold", size: 10, relativeTo: .caption2))
                        .tracking(1.5)
                        .foregroundStyle(KokoInk.coral)
                }
                if let member = community.currentMember {
                    KokoPersonalIdentityCard(member: member, wornKeepsake: KokoCommunity.keepsakes.first(where: { $0.id == community.journal?.wornKeepsakeID })) {
                        navigation.open(.editProfile)
                    }
                }
                KokoPersonalConnectionsStrip(
                    followers: community.followers.count,
                    following: community.following.count,
                    friends: community.friends.count
                ) { title in
                    navigation.open(.friends(title))
                }
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
                KokoDailyPulseCard(
                    checkedIn: community.checkedInToday,
                    level: community.activityLevel,
                    points: community.activityPoints % 200
                ) { navigation.open(.checkIn) }
                KokoPersonalActionGrid {
                    navigation.open(.album)
                } saved: {
                    navigation.open(.savedMoments)
                } rooms: {
                    navigation.selectedTab = 1
                }
                KokoPersonalCollectionCard(
                    keepsakes: KokoCommunity.keepsakes,
                    ownedCount: community.journal?.ownedKeepsakes.values.reduce(0, +) ?? 0
                ) { destination in
                    navigation.open(destination)
                }
                KokoSectionTitle(title: "Make it yours")
                KokoPersonalToolsGrid {
                    navigation.open(.feedback)
                } blocked: {
                    navigation.open(.blacklist)
                } settings: {
                    navigation.open(.settings)
                }
                KokoAction(title: "Sign out", emphasis: false) { confirmLogout = true }
            }
            if confirmLogout { KokoModal(title: "Until next time?", dismiss: { confirmLogout = false }) { Text("Your profile and keepsakes will be here when you sign in with the same email."); KokoAction(title: "Sign out") { community.signOut() } } }
        }
    }
}

private struct KokoPersonalIdentityCard: View {
    let member: CommunityMember
    let wornKeepsake: RoomKeepsake?
    let edit: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                ZStack(alignment: .bottomTrailing) {
                    KokoMemberPortrait(member: member)
                        .frame(width: 104, height: 118)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(KokoInk.accent.opacity(0.72), lineWidth: 2) }
                    Text("YOU")
                        .font(.custom("AvenirNext-Bold", size: 9, relativeTo: .caption2))
                        .tracking(1.1)
                        .foregroundStyle(KokoInk.onMint)
                        .padding(.horizontal, 9).padding(.vertical, 6)
                        .background(KokoControlSurface(highlighted: true))
                        .clipShape(Capsule())
                        .offset(x: 8, y: 7)
                }
                VStack(alignment: .leading, spacing: 7) {
                    Text("YOUR CORNER")
                        .font(.custom("AvenirNext-Bold", size: 10, relativeTo: .caption2))
                        .tracking(1.5).foregroundStyle(KokoInk.coral)
                    Text(member.publicName.isEmpty ? "Your name" : member.publicName)
                        .font(.custom("AvenirNext-Bold", size: 25, relativeTo: .title2))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(member.introductionLine.isEmpty ? "Add a little about yourself." : member.introductionLine)
                        .font(.custom("AvenirNext-Regular", size: 13, relativeTo: .body))
                        .foregroundStyle(KokoInk.secondary).lineLimit(3)
                    Button(action: edit) {
                        Text("Edit your profile")
                            .font(.custom("AvenirNext-DemiBold", size: 13, relativeTo: .body))
                            .foregroundStyle(KokoInk.onMint)
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(KokoControlSurface(highlighted: true))
                    }.buttonStyle(KokoPressStyle())
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 8) {
                Artwork(sheet: .navigation, tile: 3).frame(width: 20, height: 20)
                Text(member.hometownLabel.isEmpty ? "A new hello starts here" : "Sharing from \(member.hometownLabel)")
                    .font(.custom("AvenirNext-Medium", size: 12, relativeTo: .caption))
                    .foregroundStyle(KokoInk.secondary)
                Spacer(minLength: 0)
                if let wornKeepsake {
                    Text("Wearing \(wornKeepsake.keepsakeName)")
                        .font(.custom("AvenirNext-DemiBold", size: 10, relativeTo: .caption2))
                        .foregroundStyle(KokoInk.accent)
                        .lineLimit(1)
                }
            }
        }
        .padding(20)
        .background(ArtworkSurface(tile: 3))
    }
}

private struct KokoPersonalConnectionsStrip: View {
    let followers: Int
    let following: Int
    let friends: Int
    let open: (String) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("PEOPLE AROUND YOU").font(.custom("AvenirNext-Bold", size: 10, relativeTo: .caption2)).tracking(1.4).foregroundStyle(KokoInk.coral)
                Spacer()
                Text("Tap a count to connect").font(.custom("AvenirNext-Medium", size: 10)).foregroundStyle(KokoInk.secondary)
            }
            HStack(spacing: 8) {
                connection("Followers", followers, "Followers")
                connection("Following", following, "Following")
                connection("Friends", friends, "Friends")
            }
        }
        .padding(16)
        .background(ArtworkSurface())
    }
    private func connection(_ label: String, _ count: Int, _ destination: String) -> some View {
        Button { open(destination) } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(count)").font(.custom("AvenirNext-Bold", size: 22, relativeTo: .title3))
                Text(label).font(.custom("AvenirNext-Medium", size: 10, relativeTo: .caption)).foregroundStyle(KokoInk.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.buttonStyle(KokoPressStyle())
    }
}

private struct KokoDailyPulseCard: View {
    let checkedIn: Bool
    let level: Int
    let points: Int
    let open: () -> Void
    var body: some View {
        Button(action: open) {
            HStack(spacing: 14) {
                Artwork(sheet: .navigation, tile: 15)
                    .frame(width: 25, height: 25)
                    .padding(16)
                    .background(KokoControlSurface())
                VStack(alignment: .leading, spacing: 5) {
                    Text(checkedIn ? "You showed up today" : "Leave a little hello")
                        .font(.custom("AvenirNext-Bold", size: 17, relativeTo: .headline))
                    Text("Level \(level) · \(points)/200 points")
                        .font(.custom("AvenirNext-Medium", size: 12, relativeTo: .caption)).foregroundStyle(KokoInk.secondary)
                    Text(checkedIn ? "Come back tomorrow →" : "Check in with your people →")
                        .font(.custom("AvenirNext-DemiBold", size: 12, relativeTo: .caption)).foregroundStyle(KokoInk.accent)
                }
                Spacer(minLength: 0)
                Artwork(sheet: .navigation, tile: 5).rotationEffect(.degrees(180)).frame(width: 18, height: 18).foregroundStyle(KokoInk.coral)
            }
            .foregroundStyle(KokoInk.primary).padding(16).background(ArtworkSurface(tile: 3))
        }.buttonStyle(KokoPressStyle())
    }
}

private struct KokoPersonalActionGrid: View {
    let album: () -> Void
    let saved: () -> Void
    let rooms: () -> Void
    var body: some View {
        HStack(spacing: 8) {
            action("Album", "Keep your moments", 3, album)
            action("Saved", "Little favorites", 8, saved)
            action("Rooms", "Your conversations", 13, rooms)
        }
    }
    private func action(_ title: String, _ detail: String, _ artwork: Int, _ open: @escaping () -> Void) -> some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 8) {
                Artwork(sheet: .navigation, tile: artwork).frame(width: 28, height: 28).foregroundStyle(KokoInk.accent)
                Text(title).font(.custom("AvenirNext-DemiBold", size: 14, relativeTo: .body))
                Text(detail).font(.custom("AvenirNext-Regular", size: 10, relativeTo: .caption2)).foregroundStyle(KokoInk.secondary).lineLimit(2)
            }.frame(maxWidth: .infinity, minHeight: 92, alignment: .leading).padding(12).foregroundStyle(KokoInk.primary).background(ArtworkSurface(tile: 2))
        }.buttonStyle(KokoPressStyle())
    }
}

private struct KokoPersonalToolsGrid: View {
    let feedback: () -> Void
    let blocked: () -> Void
    let settings: () -> Void
    var body: some View {
        HStack(spacing: 8) {
            tool("Feedback", "Tell us what to tune", 2, feedback)
            tool("Blocked", "Manage your boundaries", 14, blocked)
            tool("Settings", "Shape your space", 11, settings)
        }
    }
    private func tool(_ title: String, _ detail: String, _ icon: Int, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 7) {
                Artwork(sheet: .navigation, tile: icon)
                    .frame(width: 22, height: 22)
                    .foregroundStyle(KokoInk.accent)
                Text(title).font(.custom("AvenirNext-DemiBold", size: 12, relativeTo: .caption))
                Text(detail).font(.custom("AvenirNext-Medium", size: 9, relativeTo: .caption2))
                    .foregroundStyle(KokoInk.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
            .padding(12)
            .foregroundStyle(KokoInk.primary)
            .background(ArtworkSurface(tile: 2))
        }
        .buttonStyle(KokoPressStyle())
    }
}

private struct KokoPersonalCollectionCard: View {
    let keepsakes: [RoomKeepsake]
    let ownedCount: Int
    let open: (KokoDestination) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("YOUR LITTLE WORLD").font(.custom("AvenirNext-Bold", size: 10, relativeTo: .caption2)).tracking(1.4).foregroundStyle(KokoInk.coral)
                    Text("Collected by you").font(.custom("AvenirNext-Bold", size: 21, relativeTo: .title3))
                }
                Spacer(minLength: 0)
                Text("\(ownedCount) kept")
                    .font(.custom("AvenirNext-Medium", size: 11, relativeTo: .caption)).foregroundStyle(KokoInk.secondary)
            }
            HStack(spacing: 10) {
                ForEach(Array(keepsakes.prefix(3))) { keepsake in
                    VStack(spacing: 6) {
                        Artwork(sheet: .collection, tile: keepsake.artworkTile)
                            .frame(height: 54)
                            .padding(8)
                            .background(KokoInk.canvas.opacity(0.28))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        Text(keepsake.keepsakeName).font(.custom("AvenirNext-Medium", size: 10, relativeTo: .caption2)).lineLimit(1)
                    }.frame(maxWidth: .infinity)
                }
            }
            HStack(spacing: 8) {
                collectionButton("Shop keepsakes", .shop)
                collectionButton("Open backpack", .backpack)
                collectionButton("View level", .level)
            }
        }
        .padding(18)
        .background(ArtworkSurface(tile: 5))
    }
    private func collectionButton(_ title: String, _ destination: KokoDestination) -> some View {
        Button { open(destination) } label: {
            Text(title).font(.custom("AvenirNext-DemiBold", size: 11, relativeTo: .caption)).foregroundStyle(KokoInk.primary).frame(maxWidth: .infinity, minHeight: 42).background(KokoControlSurface())
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
                                Artwork(sheet: .navigation, tile: 2)
                                    .frame(width: 24, height: 24)
                                    .padding(14)
                                    .background(KokoControlSurface())
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
                                Artwork(sheet: .navigation, tile: 13)
                                    .frame(width: 24, height: 24)
                                    .padding(14)
                                    .background(KokoControlSurface())
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
                                Artwork(sheet: .navigation, tile: 3)
                                    .frame(width: 24, height: 24)
                                    .padding(12)
                                    .background(KokoControlSurface())
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("A little context").font(.custom("AvenirNext-Bold", size: 18))
                                    Text(community.friends.contains(memberID) ? "You have a sample mutual connection." : "This profile is a preview on your device.").font(.custom("AvenirNext-Regular", size: 13))
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
                        Text("Remove this photograph from your album? It remains in the collection.")
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
                        Text("Remove this illustration from your album?")
                        KokoAction(title: "Remove illustration") {
                            if community.update({ $0.albumTiles.remove(at: index) }) { viewingLegacyIndex = nil; deletionConfirmation = false }
                        }
                    } else { KokoAction(title: "Remove from album", emphasis: false) { deletionConfirmation = true } }
                }
            }
        }
    }
}
