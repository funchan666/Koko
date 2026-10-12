import SwiftUI

struct KokoPersonalSpace: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @State private var confirmLogout = false

    var body: some View {
        ZStack {
            KokoPage {
                if let member = community.currentMember {
                    KokoPersonalIdentityCard(member: member) { navigation.open(.editProfile) }
                }
                KokoPersonalConnectionsStrip(
                    followers: community.followers.count,
                    following: community.following.count,
                    friends: community.friends.count
                ) { navigation.open(.friends($0)) }

                HStack(alignment: .top, spacing: 12) {
                    KokoPersonalWalletCard(balance: community.coinBalance) { navigation.open(.wallet) }
                    KokoDailyPulseCard(checkedIn: community.checkedInToday,
                                       level: community.activityLevel,
                                       points: community.activityPoints % 200) { navigation.open(.checkIn) }
                }
                KokoPersonalActionGrid {
                    navigation.open(.album)
                } saved: {
                    navigation.open(.savedMoments)
                } rooms: {
                    navigation.selectedTab = 1
                }
                KokoConnectionEntry(title: "In your own words", detail: "Little answers. More you.",
                                    artwork: "KokoPersonalAnswerObject") { navigation.open(.personalAnswers(nil)) }
                KokoStudioEntry()
                KokoPersonalCollectionCard(
                    ownedCount: community.journal?.ownedKeepsakes.values.reduce(0, +) ?? 0
                ) { navigation.open($0) }
                KokoPersonalToolsGrid {
                    navigation.open(.feedback)
                } blocked: {
                    navigation.open(.blacklist)
                } settings: {
                    navigation.open(.settings)
                } signOut: {
                    confirmLogout = true
                }
            }
            if confirmLogout {
                KokoModal(title: "Until next time?", presentation: .connection, dismiss: { confirmLogout = false }) {
                    Text("Your profile and keepsakes will be here when you sign in with the same email.")
                    KokoAction(title: "Sign out") { confirmLogout = false; community.signOut() }
                }
            }
        }
    }
}

private struct KokoPersonalIdentityCard: View {
    let member: CommunityMember
    let edit: () -> Void
    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            KokoMemberPortrait(member: member)
                .frame(width: 96, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            VStack(alignment: .leading, spacing: 9) {
                Text(member.publicName.isEmpty ? "Your name" : member.publicName)
                    .font(KokoTypography.heading(size: 28, relativeTo: .title))
                    .fixedSize(horizontal: false, vertical: true)
                if !member.introductionLine.isEmpty {
                    Text(member.introductionLine)
                        .font(KokoTypography.body(size: 13))
                        .foregroundStyle(KokoInk.secondary)
                        .lineLimit(3)
                }
                if !member.hometownLabel.isEmpty {
                    Text(member.hometownLabel)
                        .font(KokoTypography.medium(size: 11))
                        .foregroundStyle(KokoInk.secondary)
                }
                Button(action: edit) {
                    Text("Edit profile →")
                        .font(KokoTypography.emphasis(size: 13))
                        .foregroundStyle(KokoInk.accent)
                        .frame(minHeight: 44, alignment: .leading)
                }.buttonStyle(KokoPressStyle())
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 6)
        .padding(.bottom, 4)
    }
}

private struct KokoPersonalConnectionsStrip: View {
    let followers: Int
    let following: Int
    let friends: Int
    let open: (String) -> Void
    var body: some View {
        HStack(spacing: 12) {
            connection("Followers", followers)
            connection("Following", following)
            connection("Friends", friends)
        }.padding(.vertical, 4)
    }
    private func connection(_ label: String, _ count: Int) -> some View {
        Button { open(label) } label: {
            VStack(spacing: 3) {
                Text("\(count)").font(KokoTypography.heading(size: 23))
                Text(LocalizedStringKey(label)).font(KokoTypography.medium(size: 11)).foregroundStyle(KokoInk.secondary)
            }.frame(maxWidth: .infinity, minHeight: 62)
        }.buttonStyle(KokoPressStyle()).accessibilityLabel("\(count) \(label)")
    }
}

private struct KokoPersonalWalletCard: View {
    let balance: Int
    let open: () -> Void
    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Koko coins").font(KokoTypography.emphasis(size: 12))
                Text("\(balance)").font(KokoTypography.heading(size: 28))
                    .lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                Text("Top up →").font(KokoTypography.heading(size: 11))
            }
            .foregroundStyle(KokoInk.canvas)
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 132)
            .background { Image("KokoPersonalWalletCard").resizable().accessibilityHidden(true) }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }.buttonStyle(KokoPressStyle()).accessibilityLabel("Wallet, \(balance) coins. Top up")
    }
}

private struct KokoDailyPulseCard: View {
    let checkedIn: Bool
    let level: Int
    let points: Int
    let open: () -> Void
    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 5) {
                Text(LocalizedStringKey(checkedIn ? "Hello, again" : "Daily hello"))
                    .font(KokoTypography.emphasis(size: 12))
                Text("Level \(level)").font(KokoTypography.heading(size: 21))
                Text("\(points)/200 pts").font(KokoTypography.medium(size: 10))
                Spacer(minLength: 0)
                Text(LocalizedStringKey(checkedIn ? "Checked in" : "Check in →"))
                    .font(KokoTypography.heading(size: 11))
            }
            .foregroundStyle(KokoInk.canvas)
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 132)
            .background { Image("KokoPersonalCheckInCard").resizable().accessibilityHidden(true) }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }.buttonStyle(KokoPressStyle())
    }
}

private struct KokoPersonalActionGrid: View {
    let album: () -> Void
    let saved: () -> Void
    let rooms: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            action("Album", "KokoPersonalAlbumButton", album)
            action("Saved", "KokoPersonalSavedButton", saved)
            action("Rooms", "KokoPersonalRoomsButton", rooms)
        }.padding(.vertical, 8)
    }
    private func action(_ title: String, _ image: String, _ open: @escaping () -> Void) -> some View {
        Button(action: open) {
            VStack(spacing: 8) {
                Image(image).resizable().scaledToFit().frame(width: 54, height: 54).accessibilityHidden(true)
                Text(LocalizedStringKey(title)).font(KokoTypography.emphasis(size: 13))
            }.frame(maxWidth: .infinity, minHeight: 88)
        }.buttonStyle(KokoPressStyle()).accessibilityLabel(Text(LocalizedStringKey(title)))
    }
}

private struct KokoPersonalCollectionCard: View {
    @Environment(\.dynamicTypeSize) private var textSize
    let ownedCount: Int
    let open: (KokoDestination) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    collectionTitle
                    Spacer(minLength: 0)
                    collectionCount
                }
                VStack(alignment: .leading, spacing: 4) { collectionTitle; collectionCount }
            }
            let layout = textSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
            layout {
                collectionButton("Keepsakes", image: "KokoCollectionKeepsakeButton", destination: .shop)
                collectionButton("Backpack", image: "KokoCollectionBackpackButton", destination: .backpack)
                collectionButton("Your level", image: "KokoCollectionLevelButton", destination: .level)
            }
        }
        .foregroundStyle(KokoInk.canvas)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { Image("KokoCollectionMintSurface").resizable().accessibilityHidden(true) }
    }
    private var collectionTitle: some View {
        Text("Your collection").font(KokoTypography.heading(size: 18, relativeTo: .headline))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
    private var collectionCount: some View {
        Text("\(ownedCount) kept").font(KokoTypography.medium(size: 12, relativeTo: .caption))
            .fixedSize().foregroundStyle(KokoInk.canvas.opacity(0.72))
    }
    private func collectionButton(_ title: String, image: String, destination: KokoDestination) -> some View {
        Button { open(destination) } label: {
            VStack(spacing: 8) {
                Image(image).resizable().scaledToFit()
                    .frame(width: 54, height: 54).accessibilityHidden(true)
                Text(LocalizedStringKey(title))
                    .font(KokoTypography.emphasis(size: 12, relativeTo: .subheadline))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .top)
            .contentShape(Rectangle())
        }.buttonStyle(KokoPressStyle())
    }
}

private struct KokoPersonalToolsGrid: View {
    let feedback: () -> Void
    let blocked: () -> Void
    let settings: () -> Void
    let signOut: () -> Void
    var body: some View {
        VStack(spacing: 2) {
            tool("Settings", "Account & preferences", settings)
            tool("Blocked people", "Your boundaries", blocked)
            tool("Feedback", "Help shape Koko", feedback)
            Button(action: signOut) {
                Text("Sign out")
                    .font(KokoTypography.emphasis(size: 13, relativeTo: .body))
                    .foregroundStyle(KokoInk.canvas.opacity(0.75))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }.buttonStyle(KokoPressStyle()).padding(.top, 6)
        }
        .padding(.horizontal, 22).padding(.vertical, 14)
        .background { Image("KokoCollectionMintSurface").resizable().accessibilityHidden(true) }
    }
    private func tool(_ title: String, _ detail: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(LocalizedStringKey(title))
                        .font(KokoTypography.emphasis(size: 15, relativeTo: .body))
                        .foregroundStyle(KokoInk.canvas)
                    Text(LocalizedStringKey(detail))
                        .font(KokoTypography.medium(size: 11, relativeTo: .caption))
                        .foregroundStyle(KokoInk.canvas.opacity(0.72))
                }.fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Text("→").font(KokoTypography.medium(size: 19))
                    .foregroundStyle(KokoInk.canvas.opacity(0.6)).accessibilityHidden(true)
            }.padding(.vertical, 5)
                .frame(maxWidth: .infinity, minHeight: 58)
                .contentShape(Rectangle())
        }.buttonStyle(KokoPressStyle())
    }
}

struct KokoMemberProfile: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @Environment(\.dynamicTypeSize) private var textSize
    let memberID: String
    @State private var safety = false
    @State private var showsOptions = false
    @State private var confirmsBlock = false
    @State private var contentTab = "Moments"
    private var visibleMoments: [SharedMoment] {
        community.moments.filter {
            $0.creatorMemberID == memberID
                && ($0.libraryAssetKey == nil || $0.libraryAssetKey != community.member(memberID)?.suppliedPortraitPhotoKey)
        }
    }
    private var visibleRooms: [HostedConversationRoom] { community.rooms.filter { $0.hostMemberID == memberID } }

    var body: some View {
        ZStack {
            KokoPage(back: navigation.back, openContentOptions: memberID == community.myID ? nil : { showsOptions = true; confirmsBlock = false }) {
                if let member = community.member(memberID), community.isMemberVisible(memberID) {
                    profileHero(member)
                    profileIdentity(member)
                    profileStory(member)
                    if memberID != community.myID { profileActions }
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            profileContentTab("Moments", count: visibleMoments.count)
                            profileContentTab("Rooms", count: visibleRooms.count)
                        }
                    }.padding(.top, 6)
                    if contentTab == "Moments" {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: textSize.isAccessibilitySize ? 1 : 2), spacing: 14) {
                            ForEach(visibleMoments) { KokoMomentCard(moment: $0) }
                        }
                        if visibleMoments.isEmpty { Text("No moments to show yet.").foregroundStyle(KokoInk.secondary) }
                    } else {
                        ForEach(visibleRooms) { profileRoom($0) }
                        if visibleRooms.isEmpty { Text("No rooms to show yet.").foregroundStyle(KokoInk.secondary) }
                    }
                    KokoAnswerCards(member: member)
                } else if community.journal?.blockedMembers.contains(memberID) == true {
                    KokoEmpty(title: "Person blocked", detail: "This profile and its content are hidden.")
                    KokoAction(title: "Unblock", emphasis: false) { _ = community.unblock(memberID) }
                } else {
                    KokoEmpty(title: "Profile not found", detail: "This profile is no longer available here.")
                }
            }.allowsHitTesting(!safety && !showsOptions).accessibilityHidden(safety || showsOptions)
            if showsOptions { profileOptions }
            if safety {
                KokoSafetyPanel(reportedContentID: memberID, memberID: memberID) {
                    safety = false
                    if community.journal?.blockedMembers.contains(memberID) == true { navigation.back() }
                }
            }

        }
    }

    private func profileHero(_ member: CommunityMember) -> some View {
        // One photo only: no inset portrait, image border or text covering the face.
        KokoMemberCoverPhoto(member: member)
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .accessibilityLabel(Text(verbatim: member.publicName))
    }

    private func profileIdentity(_ member: CommunityMember) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 16) {
                    profileName(member)
                    Spacer(minLength: 0)
                    if memberID != community.myID { followButton }
                }
                VStack(alignment: .leading, spacing: 8) {
                    profileName(member)
                    if memberID != community.myID { followButton }
                }
            }
            let details = [member.adultAge >= 18 ? String(member.adultAge) : "", member.hometownLabel, member.spokenLanguage]
                .filter { !$0.isEmpty }.joined(separator: " · ")
            if !details.isEmpty {
                Text(verbatim: details).font(KokoTypography.medium(size: 13, relativeTo: .subheadline))
                    .foregroundStyle(KokoInk.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if community.friends.contains(memberID) {
                Text("Mutual").font(KokoTypography.emphasis(size: 11)).foregroundStyle(KokoInk.accent)
            }
        }.padding(.horizontal, 3)
    }
    private func profileName(_ member: CommunityMember) -> some View {
        Text(verbatim: member.publicName).font(KokoTypography.heading(size: 27, relativeTo: .title))
            .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
    }
    private var followButton: some View {
        profileButton(community.following.contains(memberID) ? "Unfollow" : (community.followers.contains(memberID) ? "Follow back" : "Follow"), prominent: false) {
            community.toggleFollow(memberID)
        }.fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder private func profileStory(_ member: CommunityMember) -> some View {
        if !member.introductionLine.isEmpty || !member.interests.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                if !member.introductionLine.isEmpty {
                    Text(verbatim: member.introductionLine)
                        .font(KokoTypography.medium(size: 16, relativeTo: .body))
                        .foregroundStyle(KokoInk.primary).fixedSize(horizontal: false, vertical: true)
                }
                if !member.interests.isEmpty {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) { interestItems(member) }
                        VStack(alignment: .leading, spacing: 8) { interestItems(member) }
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 3)
        }
    }

    @ViewBuilder private func interestItems(_ member: CommunityMember) -> some View {
        ForEach(member.interests, id: \.self) { interest in
            HStack(spacing: 6) {
                Image(interestArtwork(interest)).resizable().scaledToFit().frame(width: 22, height: 22).accessibilityHidden(true)
                Text(LocalizedStringKey(interest)).font(KokoTypography.emphasis(size: 12, relativeTo: .caption))
                    .fixedSize(horizontal: false, vertical: true)
            }.padding(.horizontal, 10).padding(.vertical, 7)
                .background(KokoControlSurface()).foregroundStyle(KokoInk.accent)
        }
    }

    private func interestArtwork(_ interest: String) -> String {
        switch interest {
        case "Music": "KokoDiscoverMusic"
        case "Creative": "KokoDiscoverCreative"
        case "After hours": "KokoDiscoverAfterHours"
        default: "KokoDiscoverConversation"
        }
    }

    private var profileActions: some View {
        VStack(spacing: 10) {
            Button { navigation.open(.conversation(memberID)) } label: {
                HStack(spacing: 9) {
                    Image("KokoDiscoverConversation").resizable().scaledToFit().frame(width: 27, height: 27).accessibilityHidden(true)
                    Text("Send a hello").font(KokoTypography.heading(size: 16, relativeTo: .body))
                }.foregroundStyle(KokoInk.canvas).frame(maxWidth: .infinity, minHeight: 54)
                    .background { Image("KokoProfileHelloSurface").resizable().accessibilityHidden(true) }
            }.buttonStyle(KokoPressStyle())
            let layout = textSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 10))
            layout {
                profileCallButton("Voice call", image: "KokoProfileVoiceCall", channel: .voice)
                profileCallButton("Video call", image: "KokoProfileVideoCall", channel: .video)
            }
            Button { navigation.open(.conversationStarters(memberID)) } label: {
                HStack(spacing: 7) {
                    Text("Choose an icebreaker →").font(KokoTypography.emphasis(size: 12, relativeTo: .body))
                    Spacer(minLength: 0)
                }.foregroundStyle(KokoInk.accent).frame(maxWidth: .infinity, minHeight: 44)
            }.buttonStyle(KokoPressStyle())
        }
    }

    private func profileCallButton(_ title: String, image: String, channel: KokoConversationChannel) -> some View {
        Button { navigation.open(.call(memberID, channel)) } label: {
            Text(LocalizedStringKey(title))
                .font(KokoTypography.heading(size: 13, relativeTo: .subheadline))
                .foregroundStyle(KokoInk.canvas).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 49).padding(.trailing, 12).padding(.vertical, 18)
                .frame(maxWidth: .infinity, minHeight: 72)
                .background { Image(image).resizable().accessibilityHidden(true) }
                .contentShape(Rectangle())
        }.buttonStyle(KokoPressStyle())
    }

    private func profileContentTab(_ title: String, count: Int) -> some View {
        Button { contentTab = title } label: {
            HStack(spacing: 6) {
                Text(LocalizedStringKey(title))
                Text("\(count)").font(KokoTypography.heading(size: 16))
            }.font(KokoTypography.emphasis(size: 13)).frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(contentTab == title ? KokoInk.canvas : KokoInk.secondary)
                .background {
                    if contentTab == title { Image("KokoVoiceTopicSelection").resizable().accessibilityHidden(true) }
                }
                .contentShape(Rectangle())
        }.buttonStyle(KokoPressStyle()).accessibilityAddTraits(contentTab == title ? .isSelected : [])
    }

    private var profileOptions: some View {
        KokoModal(title: confirmsBlock ? "Block this person?" : "More", presentation: confirmsBlock ? .safety : .compact, dismiss: { showsOptions = false }) {
            if confirmsBlock {
                Text("Their rooms, moments and conversations will be hidden on this device. You can undo this in your blocked list.")
                KokoAction(title: "Block person") {
                    if community.block(memberID) { showsOptions = false; navigation.back() }
                }
                KokoAction(title: "Go back", emphasis: false) { confirmsBlock = false }
            } else {
                KokoAction(title: "Report", emphasis: false) { showsOptions = false; safety = true }
                KokoAction(title: "Block this person", emphasis: false) { confirmsBlock = true }
            }
        }
    }

    private func profileButton(_ title: String, prominent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(LocalizedStringKey(title))
                .font(KokoTypography.emphasis(size: prominent ? 16 : 13, relativeTo: .body))
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(prominent ? KokoInk.canvas : KokoInk.paper)
                .padding(.horizontal, 18).padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background { Image(prominent ? "KokoProfileHelloSurface" : "KokoProfileQuietSurface").resizable().accessibilityHidden(true) }
                .contentShape(Rectangle())
        }.buttonStyle(KokoPressStyle())
    }

    private func profileRoom(_ room: HostedConversationRoom) -> some View {
        Button { navigation.open(.room(room.id)) } label: {
            VStack(alignment: .leading, spacing: 9) {
                Text(LocalizedStringKey(room.conversationTopic))
                    .font(KokoTypography.emphasis(size: 12, relativeTo: .caption))
                    .foregroundStyle(KokoInk.canvas.opacity(0.65))
                Text(verbatim: room.roomTitle).font(KokoTypography.heading(size: 21, relativeTo: .headline))
                Text(verbatim: room.conversationPrompt)
                    .font(KokoTypography.medium(size: 13, relativeTo: .body))
                Text(LocalizedStringKey(room.isVideoStage ? "Video preview" : "Voice room preview"))
                    .font(KokoTypography.medium(size: 11, relativeTo: .caption))
                Text("Enter room →").font(KokoTypography.heading(size: 13, relativeTo: .body)).frame(minHeight: 44)
            }.foregroundStyle(KokoInk.canvas).fixedSize(horizontal: false, vertical: true)
                .padding(22).frame(maxWidth: .infinity, alignment: .leading)
                .background { Image("KokoProfileStoryPaper").resizable().accessibilityHidden(true) }
                .contentShape(Rectangle())
        }.buttonStyle(KokoPressStyle())
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
            if members.isEmpty { KokoEmpty(title: "Good company takes a first hello", detail: "Follow someone from their profile. A friendship starts only when they follow you back."); KokoAction(title: "Explore people", icon: 4) { navigation.open(.search) } }
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
                KokoModal(title: "Choose a photograph", presentation: .selection, dismiss: { picker = false }) {
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
                KokoModal(title: "Your album", presentation: .selection, dismiss: { viewingPhotoKey = nil; deletionConfirmation = false }) {
                    KokoContentImage(asset: photo, fullResolution: true, fitInside: true).frame(height: 370)
                    Text(photo.captionLine).font(KokoTypography.emphasis(size: 16))
                    if deletionConfirmation {
                        Text("Remove this photograph from your album? It remains in the collection.")
                        KokoAction(title: "Remove photo") {
                            if community.update({ $0.albumPhotoKeys?.removeAll { $0 == photo.id } }) { viewingPhotoKey = nil; deletionConfirmation = false }
                        }
                    } else { KokoAction(title: "Remove from album", emphasis: false) { deletionConfirmation = true } }
                }
            }
            if let index = viewingLegacyIndex, let tiles = community.journal?.albumTiles, tiles.indices.contains(index) {
                KokoModal(title: "Saved illustration", presentation: .selection, dismiss: { viewingLegacyIndex = nil; deletionConfirmation = false }) {
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
