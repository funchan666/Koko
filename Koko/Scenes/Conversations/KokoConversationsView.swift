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
                    KokoIconAction(icon: 3, label: "My album") { navigation.open(.album) }
                }
                KokoConversationSectionHeading(title: "Conversations", subtitle: "Keep the thread going") {
                    if !community.conversations.isEmpty { confirmClear = true }
                }
                if filtered.isEmpty {
                    KokoFirstHelloCard(searching: !search.isEmpty) { navigation.open(.search) }
                }
                ForEach(filtered) { conversation in
                    KokoMenuRow(title: community.member(conversation.correspondentID)?.publicName ?? "Conversation", detail: conversation.entries.last.map { $0.messageText.isEmpty && $0.attachmentPhotoKey != nil ? "Photo from the collection" : $0.messageText } ?? (conversation.compositionDraft.isEmpty ? "A new conversation" : "Draft: " + conversation.compositionDraft), icon: 2) {
                        community.update { journal in if let index = journal.privateConversations.firstIndex(where: { $0.id == conversation.id }) { journal.privateConversations[index].unreadEntries = 0 } }
                        navigation.open(.conversation(conversation.correspondentID))
                    }
                }
                let friendsRooms = community.rooms.filter { community.friends.contains($0.hostMemberID) }
                KokoConversationSectionHeading(title: "Friends’ rooms", subtitle: "People you already know are here")
                if friendsRooms.isEmpty {
                    KokoFriendsRoomInviteCard { navigation.open(.friends("Friends")) }
                } else { ForEach(friendsRooms) { KokoRoomCard(room: $0) } }
            }
            if confirmClear {
                KokoModal(title: "Clear your conversations?", dismiss: { confirmClear = false }) {
                    Text("This removes all conversation entries and drafts from this device. Your friendships stay.")
                    KokoAction(title: "Clear conversations") { community.update { $0.privateConversations = [] }; confirmClear = false }
                    KokoAction(title: "Keep them", emphasis: false) { confirmClear = false }
                }
            }
        }
    }

}

private struct KokoConversationPulseRail: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    let unread: Int
    let friendCount: Int
    var body: some View {
        HStack(spacing: 10) {
            pulseButton(title: "Inbox", detail: unread == 0 ? "All caught up" : "\(unread) to open", icon: 10) { navigation.open(.notices) }
            pulseButton(title: "Friends", detail: "\(friendCount) nearby", icon: 3) { navigation.open(.friends("Friends")) }
            pulseButton(title: "Pulse", detail: "Community", icon: 15) { navigation.open(.ranking) }
        }
    }
    private func pulseButton(title: String, detail: String, icon: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    Artwork(sheet: .navigation, tile: icon).frame(width: 25, height: 25)
                    Spacer(minLength: 0)
                }
                Text(title).font(.custom("AvenirNext-Bold", size: 13, relativeTo: .subheadline))
                Text(detail).font(.custom("AvenirNext-Medium", size: 9, relativeTo: .caption2)).foregroundStyle(KokoInk.secondary).lineLimit(1)
            }
            .foregroundStyle(KokoInk.primary)
            .padding(12).frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
            .background(ArtworkSurface(tile: title == "Inbox" ? 3 : 2))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }.buttonStyle(KokoPressStyle())
    }
}

private struct KokoConversationSectionHeading: View {
    let title: String
    let subtitle: String
    var clear: (() -> Void)? = nil
    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.custom("AvenirNext-Bold", size: 20, relativeTo: .title3))
                Text(subtitle).font(.custom("AvenirNext-Medium", size: 10)).foregroundStyle(KokoInk.secondary)
            }
            Spacer(minLength: 0)
            if let clear {
                Button(action: clear) {
                    Artwork(sheet: .navigation, tile: 6).frame(width: 24, height: 24)
                }.buttonStyle(.plain).accessibilityLabel("Clear conversations")
            }
        }
    }
}

private struct KokoFirstHelloCard: View {
    let searching: Bool
    let action: () -> Void
    var body: some View {
        VStack(spacing: 10) {
            Artwork(sheet: .navigation, tile: 2).frame(width: 28, height: 28)
                .padding(15)
                .background(KokoControlSurface())
            Text(searching ? "No one matches that yet" : "A hello starts here").font(.custom("AvenirNext-Bold", size: 19))
            Text(searching ? "Try another name or look around the community." : "Find someone nearby, then send a small hello.")
                .font(.custom("AvenirNext-Regular", size: 12)).foregroundStyle(KokoInk.secondary).multilineTextAlignment(.center)
            KokoAction(title: "Find someone to talk to", icon: 4, action: action).frame(maxWidth: 270)
        }.frame(maxWidth: .infinity).padding(22).background(ArtworkSurface(tile: 3))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct KokoFriendsRoomInviteCard: View {
    let action: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Artwork(sheet: .navigation, tile: 3)
                .frame(width: 25, height: 25)
                .padding(14)
                .background(KokoControlSurface())
            VStack(alignment: .leading, spacing: 5) {
                Text("Bring your people together").font(.custom("AvenirNext-Bold", size: 15))
                Text("Open a room and make space for a shared hello.").font(.custom("AvenirNext-Medium", size: 10)).foregroundStyle(KokoInk.secondary).lineLimit(2)
                Button("See your friends →", action: action).font(.custom("AvenirNext-Bold", size: 10)).foregroundStyle(KokoInk.coral).buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }.padding(15).background(ArtworkSurface(tile: 3)).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
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
            KokoPage(title: community.member(memberID)?.publicName ?? "Conversation", subtitle: "CONVERSATION · DELIVERY ISN’T CONNECTED YET", back: navigation.back) {
                HStack {
                    KokoAction(title: "Voice call", icon: 13) { navigation.open(.call(memberID, .voice)) }
                    KokoAction(title: "Video call", icon: 0) { navigation.open(.call(memberID, .video)) }
                }
                HStack {
                    Spacer()
                    KokoIconAction(icon: 11, label: "Report or block") { showSafety = true }
                    KokoIconAction(icon: 6, label: "Clear this chat") { showClear = true }
                }
                if !community.friends.contains(memberID) {
                    KokoCard { VStack(alignment: .leading, spacing: 12) { Text("It feels better when it's mutual.").font(.custom("AvenirNext-Bold", size: 20)); Text("Open their profile to enable a sample mutual connection before trying chat."); KokoAction(title: "Open profile", emphasis: false) { navigation.open(.profile(memberID)) } } }
                }
                let entries = community.conversation(for: memberID)?.entries ?? []
                if entries.isEmpty { KokoEmpty(title: "Leave a little hello", detail: "Messages and photo attachments are saved on this device.") }
                ForEach(entries) { entry in
                    HStack {
                        if entry.authorMemberID == community.myID { Spacer(minLength: 30) }
                        KokoCard(tint: entry.authorMemberID == community.myID ? 3 : 2) {
                            VStack(alignment: .leading, spacing: 8) {
                                if let photo = KokoMediaLibrary.asset(entry.attachmentPhotoKey) {
                                    Button { viewingPhotoKey = photo.id } label: {
                                        KokoContentImage(asset: photo).frame(height: 190)
                                    }.buttonStyle(KokoPressStyle()).accessibilityLabel("Open attached photo")
                                }
                                if let tile = entry.attachmentTile { Artwork(sheet: .collection, tile: tile).frame(height: 160) }
                                if !entry.messageText.isEmpty { Text(entry.messageText) }
                                Text(entry.postedAt, style: .time).font(.custom("AvenirNext-Regular", size: 10))
                                Text("Saved on this device").font(.custom("AvenirNext-Medium", size: 9)).foregroundStyle(KokoInk.secondary)
                            }
                        }
                        if entry.authorMemberID != community.myID { Spacer(minLength: 30) }
                    }
                }
                if let photo = KokoMediaLibrary.asset(attachment) {
                    HStack { KokoContentImage(asset: photo).frame(width: 90, height: 90); KokoAction(title: "Remove attachment", emphasis: false) { self.attachment = nil } }
                }
                KokoField(label: "Write something kind", value: $draft, multiline: true)
                HStack {
                    KokoIconAction(icon: 7, label: "Attach photo") { showAttachmentPicker = true }
                    KokoAction(title: "Save message", icon: 12) { if community.sendMessage(draft, memberID: memberID, photoKey: attachment) { draft = ""; attachment = nil } }
                }
            }
            if showAttachmentPicker {
                KokoModal(title: "Choose a photo", dismiss: { showAttachmentPicker = false }) {
                    KokoCollectionPhotoPicker(selectedPhotoKey: $attachment)
                    KokoAction(title: "Attach selection") { guard attachment != nil else { community.notice = "Choose a photo first."; return }; showAttachmentPicker = false }
                }
            }
            if let photo = KokoMediaLibrary.asset(viewingPhotoKey) {
                KokoModal(title: "Attached photo", dismiss: { viewingPhotoKey = nil }) {
                    KokoContentImage(asset: photo, fullResolution: true, fitInside: true).frame(height: 400)
                    Text(photo.captionLine).font(.custom("AvenirNext-Regular", size: 14))
                }
            }
            if showSafety { KokoSafetyPanel(subjectKey: "conversation-" + memberID, memberID: memberID) { showSafety = false; if community.journal?.blockedMembers.contains(memberID) == true { navigation.back() } } }
            if showClear {
                KokoModal(title: "Clear this chat?", dismiss: { showClear = false }) {
                    Text("Messages and the saved draft will be removed from this device.")
                    KokoAction(title: "Clear chat") { community.update { $0.privateConversations.removeAll { $0.correspondentID == memberID } }; draft = ""; attachment = nil; showClear = false }
                }
            }
        }.onAppear { draft = community.conversation(for: memberID)?.compositionDraft ?? "" }
            .onDisappear { if !draft.isEmpty { community.saveDraft(draft, memberID: memberID) } }
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
                        Text(notice.headline).font(.custom("AvenirNext-Bold", size: 20))
                        Text(notice.explanation).font(.custom("AvenirNext-Regular", size: 14))
                        Text(notice.createdAt, style: .date).font(.custom("AvenirNext-Medium", size: 11))
                        if !notice.hasBeenRead { KokoAction(title: "Mark read", emphasis: false) { community.update { journal in if let index = journal.notices.firstIndex(where: { $0.id == notice.id }) { journal.notices[index].hasBeenRead = true } } } }
                    }
                }
            }
        }
    }
}
