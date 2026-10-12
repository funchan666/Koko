import SwiftUI

struct KokoConversationsView: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @State private var search = ""
    @State private var confirmClear = false
    var filtered: [PrivateConversation] { community.conversations.filter { search.isEmpty || (community.member($0.correspondentID)?.publicName.localizedCaseInsensitiveContains(search) ?? false) || ($0.entries.last?.messageText.localizedCaseInsensitiveContains(search) ?? false) } }
    var body: some View {
        ZStack {
            KokoPage {
                KokoConversationPulseRail(
                    unread: community.journal?.notices.filter { !$0.hasBeenRead }.count ?? 0,
                    friendCount: community.friends.count
                )
                HStack(spacing: 10) {
                    KokoSearchField(prompt: "Search conversations", query: $search)
                    Button { navigation.open(.album) } label: {
                        Image("KokoPersonalAlbumButton").resizable().scaledToFit()
                            .frame(width: 44, height: 44).accessibilityHidden(true)
                    }.buttonStyle(KokoPressStyle()).accessibilityLabel("My album")
                }
                if community.conversations.isEmpty {
                    KokoConversationSectionHeading(title: "Conversations", subtitle: "Keep the thread going")
                } else {
                    KokoConversationSectionHeading(title: "Conversations", subtitle: "Keep the thread going") { confirmClear = true }
                }
                if filtered.isEmpty {
                    KokoFirstHelloCard(searching: !search.isEmpty) { navigation.open(.search) }
                }
                ForEach(filtered) { conversation in
                    VStack(alignment: .leading, spacing: 8) {
                        if let member = community.member(conversation.correspondentID) {
                            KokoProfileLink(memberID: member.id) {
                                HStack(spacing: 12) {
                                    KokoMemberPortrait(member: member).frame(width: 44, height: 44)
                                    Text(member.publicName).font(KokoTypography.emphasis(size: 17))
                                }
                            }
                        }
                        Button {
                            community.update { journal in if let index = journal.privateConversations.firstIndex(where: { $0.id == conversation.id }) { journal.privateConversations[index].unreadEntries = 0 } }
                            navigation.open(.conversation(conversation.correspondentID))
                        } label: {
                            HStack {
                                Text(conversation.entries.last?.messageText ?? conversation.compositionDraft)
                                    .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                                Text("Open chat →")
                            }.font(KokoTypography.medium(size: 13)).frame(minHeight: 44)
                        }.buttonStyle(KokoPressStyle())
                    }.padding(16).background(Image("KokoConversationPaper").resizable())
                }
                let friendsRooms = community.rooms.filter { community.friends.contains($0.hostMemberID) }
                KokoConversationSectionHeading(title: "Friends’ rooms", subtitle: "People you already know are here")
                if friendsRooms.isEmpty {
                    KokoFriendsRoomInviteCard { navigation.open(.friends("Friends")) }
                } else { ForEach(friendsRooms) { KokoRoomCard(room: $0) } }
            }
            if confirmClear {
                KokoModal(title: "Clear your conversations?", presentation: .safety, dismiss: { confirmClear = false }) {
                    Text("This removes all conversation entries and drafts from this device. Your friendships stay.")
                    KokoAction(title: "Clear conversations") { community.update { $0.privateConversations = [] }; confirmClear = false }
                    KokoAction(title: "Keep them", emphasis: false) { confirmClear = false }
                }
            }
        }
    }

}

private struct KokoConversationPulseRail: View {
    @EnvironmentObject private var navigation: KokoSceneNavigation
    let unread: Int
    let friendCount: Int
    var body: some View {
        HStack(spacing: 10) {
            pulseButton(title: "Inbox", detail: unread == 0 ? "All caught up" : "\(unread) unread", artwork: "KokoInboxShortcut") { navigation.open(.notices) }
            pulseButton(title: "Friends", detail: "\(friendCount) connections", artwork: "KokoFriendsShortcut") { navigation.open(.friends("Friends")) }
            pulseButton(title: "Ranking", detail: "Community", artwork: "KokoRankingShortcut") { navigation.open(.ranking) }
        }
    }
    private func pulseButton(title: String, detail: LocalizedStringKey, artwork: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            GeometryReader { geometry in
                Image(artwork)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .accessibilityHidden(true)
                    .overlay(alignment: .bottom) {
                    VStack(spacing: 2) {
                        Text(LocalizedStringKey(title)).font(KokoTypography.heading(size: min(13, geometry.size.width * 0.12))).lineLimit(1)
                        Text(detail).font(KokoTypography.medium(size: min(9, geometry.size.width * 0.085))).lineLimit(1)
                    }
                    .foregroundStyle(KokoInk.canvas)
                    .padding(.horizontal, 6)
                    .padding(.bottom, geometry.size.height * 0.075)
                    .accessibilityHidden(true)
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(KokoPressStyle())
        .accessibilityLabel(Text(LocalizedStringKey(title)) + Text(", ") + Text(detail))
    }
}

private struct KokoConversationSectionHeading: View {
    let title: String
    let subtitle: String
    var clear: (() -> Void)? = nil
    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(title)).font(KokoTypography.heading(size: 20, relativeTo: .title3))
                Text(LocalizedStringKey(subtitle)).font(KokoTypography.medium(size: 10)).foregroundStyle(KokoInk.secondary)
            }
            Spacer(minLength: 0)
            if let clear {
                Button("Clear", action: clear)
                    .font(KokoTypography.emphasis(size: 11))
                    .foregroundStyle(KokoInk.coral)
                    .frame(minWidth: 44, minHeight: 44)
                    .buttonStyle(.plain).accessibilityLabel("Clear conversations")
            }
        }
    }
}

private struct KokoFirstHelloCard: View {
    let searching: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 9) {
                    Text(LocalizedStringKey(searching ? "Try a new connection" : "Every friendship\nstarts with hello."))
                        .font(KokoTypography.heading(size: 22))
                        .lineLimit(2)
                    Text(LocalizedStringKey(searching ? "Search another name or explore the community." : "Find someone you click with."))
                        .font(KokoTypography.medium(size: 12))
                        .lineLimit(2)
                }
                .padding(.horizontal, 22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 144)
                HStack {
                    Text("Find your people")
                    Spacer(minLength: 0)
                    Text("→")
                }
                .font(KokoTypography.heading(size: 14))
                .padding(.horizontal, 22)
                .frame(height: 54)
            }
            .foregroundStyle(KokoInk.canvas)
            .background { Image("KokoHelloInvitation").resizable().accessibilityHidden(true) }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }.buttonStyle(KokoPressStyle())
            .accessibilityLabel(Text(LocalizedStringKey(searching ? "No matching conversations. Find your people" : "Start a friendship. Find your people")))
    }
}

private struct KokoFriendsRoomInviteCard: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            GeometryReader { geometry in
                VStack(alignment: .leading, spacing: 6) {
                    Text("Better together")
                        .font(KokoTypography.heading(size: 17))
                    Text("A room for your kind of people.")
                        .font(KokoTypography.medium(size: 11))
                        .lineLimit(2)
                    Text("See your friends →")
                        .font(KokoTypography.heading(size: 11))
                        .padding(.top, 3)
                }
                .foregroundStyle(KokoInk.canvas)
                .frame(width: max(0, geometry.size.width * 0.67 - 20), height: geometry.size.height, alignment: .leading)
                .padding(.leading, 20)
            }
            .frame(height: 118)
            .background { Image("KokoFriendsRoomInvitation").resizable().accessibilityHidden(true) }
            .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
        }.buttonStyle(KokoPressStyle()).accessibilityLabel("See your friends and their rooms")
    }
}


struct KokoConversationDetail: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    let memberID: String
    @State private var draft = ""
    @State private var attachment: String?
    @State private var viewingPhotoKey: String?
    @State private var showAttachmentPicker = false
    @State private var showSafety = false
    @State private var showClear = false
    var body: some View {
        ZStack {
            KokoPage(title: "Conversation", subtitle: "CONVERSATION · DELIVERY ISN’T CONNECTED YET", back: navigation.back) {
                if community.isMemberVisible(memberID), let member = community.member(memberID) { KokoMemberRow(member: member) }
                if community.isMemberVisible(memberID) && !community.isContentHidden("conversation-" + memberID) {
                HStack {
                    KokoAction(title: "Voice call", icon: 13) { if community.requireMutualConnection(memberID) { navigation.open(.call(memberID, .voice)) } }
                    KokoAction(title: "Video call", icon: 0) { if community.requireMutualConnection(memberID) { navigation.open(.call(memberID, .video)) } }
                }
                HStack {
                    Spacer()
                    KokoIconAction(icon: 11, label: "Report or block") { showSafety = true }
                    KokoIconAction(icon: 6, label: "Clear this chat") { showClear = true }
                }
                if !community.friends.contains(memberID) {
                    KokoCard { VStack(alignment: .leading, spacing: 12) { Text("It feels better when it's mutual.").font(KokoTypography.heading(size: 20)); Text("You both need to follow each other before sending messages or starting a call."); KokoAction(title: "Open profile", emphasis: false) { navigation.open(.profile(memberID)) } } }
                }
                let entries = community.conversation(for: memberID)?.entries ?? []
                if entries.isEmpty { KokoEmpty(title: "Leave a little hello", detail: "Messages and photo attachments are saved on this device.") }
                ForEach(entries) { entry in
                    HStack {
                        if entry.authorMemberID == community.myID { Spacer(minLength: 30) }
                        KokoCard(tint: entry.authorMemberID == community.myID ? 3 : 2) {
                            VStack(alignment: .leading, spacing: 8) {
                                if let author = community.member(entry.authorMemberID) {
                                    KokoProfileLink(memberID: author.id) {
                                        HStack(spacing: 8) {
                                            KokoMemberPortrait(member: author).frame(width: 32, height: 32)
                                            Text(author.publicName).font(KokoTypography.emphasis(size: 12))
                                        }.frame(minHeight: 44)
                                    }
                                }
                                if let photo = KokoMediaLibrary.asset(entry.attachmentPhotoKey) {
                                    Button { viewingPhotoKey = photo.id } label: {
                                        KokoContentImage(asset: photo).frame(height: 190)
                                    }.buttonStyle(KokoPressStyle()).accessibilityLabel("Open attached photo")
                                }
                                if let tile = entry.attachmentTile { Artwork(sheet: .collection, tile: tile).frame(height: 160) }
                                if !entry.messageText.isEmpty { Text(entry.messageText) }
                                Text(entry.postedAt, style: .time).font(KokoTypography.body(size: 10))
                                Text("Saved on this device").font(KokoTypography.medium(size: 9)).foregroundStyle(KokoInk.secondary)
                                if entry.authorMemberID != community.myID {
                                    Button("Report") { community.safetyRequest = .init(contentID: entry.id, memberID: entry.authorMemberID) }
                                        .buttonStyle(KokoPressStyle()).frame(minHeight: 44)
                                }
                            }
                        }
                        if entry.authorMemberID != community.myID { Spacer(minLength: 30) }
                    }
                }
                if let photo = KokoMediaLibrary.asset(attachment) {
                    HStack { KokoContentImage(asset: photo).frame(width: 90, height: 90); KokoAction(title: "Remove attachment", emphasis: false) { self.attachment = nil } }
                }
                Button("Choose an icebreaker →") {
                    if community.saveDraft(draft, memberID: memberID, photoKey: attachment) {
                        navigation.open(.conversationStarters(memberID))
                    }
                }.font(KokoTypography.emphasis(size: 13, relativeTo: .body))
                    .foregroundStyle(KokoInk.accent).frame(minHeight: 44).buttonStyle(KokoPressStyle())
                KokoField(label: "Write something kind", value: $draft, multiline: true)
                HStack {
                    KokoIconAction(icon: 7, label: "Attach photo") { showAttachmentPicker = true }
                    KokoAction(title: "Save message", icon: 12) { if community.sendMessage(draft, memberID: memberID, photoKey: attachment) { draft = ""; attachment = nil } }
                }
                } else { KokoEmpty(title: "Conversation hidden", detail: "This conversation is no longer visible.") }
            }.allowsHitTesting(!showSafety && !showAttachmentPicker && !showClear && viewingPhotoKey == nil)
                .accessibilityHidden(showSafety || showAttachmentPicker || showClear || viewingPhotoKey != nil)
            if showAttachmentPicker {
                KokoModal(title: "Choose a photo", presentation: .selection, dismiss: { showAttachmentPicker = false }) {
                    KokoCollectionPhotoPicker(selectedPhotoKey: $attachment)
                    KokoAction(title: "Attach selection") { guard attachment != nil else { community.notice = "Choose a photo first."; return }; showAttachmentPicker = false }
                }
            }
            if let photo = KokoMediaLibrary.asset(viewingPhotoKey) {
                KokoModal(title: "Attached photo", presentation: .selection, dismiss: { viewingPhotoKey = nil }) {
                    KokoContentImage(asset: photo, fullResolution: true, fitInside: true).frame(height: 400)
                    Text(photo.captionLine).font(KokoTypography.body(size: 14))
                }
            }
            if showSafety { KokoSafetyPanel(reportedContentID: "conversation-" + memberID, memberID: memberID) { showSafety = false; if !community.isMemberVisible(memberID) || community.isContentHidden("conversation-" + memberID) { navigation.back() } } }
            if showClear {
                KokoModal(title: "Clear this chat?", presentation: .safety, dismiss: { showClear = false }) {
                    Text("Messages and the saved draft will be removed from this device.")
                    KokoAction(title: "Clear chat") { community.update { $0.privateConversations.removeAll { $0.correspondentID == memberID } }; draft = ""; attachment = nil; showClear = false }
                }
            }
        }.onAppear {
            draft = community.conversation(for: memberID)?.compositionDraft ?? ""
            attachment = community.conversation(for: memberID)?.compositionPhotoDraft
        }
            .onChange(of: draft) { _ in _ = community.saveDraft(draft, memberID: memberID, photoKey: attachment) }
            .onChange(of: attachment) { _ in _ = community.saveDraft(draft, memberID: memberID, photoKey: attachment) }
            .onDisappear {
                if community.conversation(for: memberID) != nil || !draft.isEmpty || attachment != nil {
                    community.saveDraft(draft, memberID: memberID, photoKey: attachment)
                }
            }
    }
}

struct KokoArtworkPicker: View {
    @Binding var selected: Int?
    var tiles: [Int]
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
            ForEach(tiles, id: \.self) { tile in
                Button { selected = tile } label: { Artwork(sheet: .collection, tile: tile).frame(height: 110).padding(10).background(ArtworkSurface(tile: selected == tile ? 3 : 2)) }.buttonStyle(.plain).accessibilityLabel("Sample image \(tile + 1)").accessibilityAddTraits(selected == tile ? .isSelected : [])
            }
        }
    }
}

struct KokoNoticesView: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    var body: some View {
        KokoPage(title: "System messages", back: navigation.back) {
            KokoAction(title: "Mark all as read", emphasis: false) { community.update { for index in $0.notices.indices { $0.notices[index].hasBeenRead = true } } }
            ForEach(community.journal?.notices ?? []) { notice in
                KokoCard(tint: notice.hasBeenRead ? 2 : 3) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(notice.headline).font(KokoTypography.heading(size: 20))
                        Text(notice.explanation).font(KokoTypography.body(size: 14))
                        Text(notice.createdAt, style: .date).font(KokoTypography.medium(size: 11))
                        if !notice.hasBeenRead { KokoAction(title: "Mark read", emphasis: false) { community.update { journal in if let index = journal.notices.firstIndex(where: { $0.id == notice.id }) { journal.notices[index].hasBeenRead = true } } } }
                    }
                }
            }
        }
    }
}
