import SwiftUI

struct KokoConversationsView: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @State private var search = ""
    @State private var confirmClear = false
    var filtered: [PrivateConversation] { community.conversations.filter { search.isEmpty || (community.member($0.correspondentID)?.publicName.localizedCaseInsensitiveContains(search) ?? false) || ($0.entries.last?.messageText.localizedCaseInsensitiveContains(search) ?? false) } }
    var body: some View {
        ZStack {
            KokoPage(title: "A little hello", subtitle: "THE CONVERSATIONS YOU COME BACK TO") {
                HStack {
                    KokoMenuRow(title: "Notices", detail: "\(community.journal?.notices.filter { !$0.hasBeenRead }.count ?? 0) unread", icon: 10) { navigation.open(.notices) }
                    KokoIconAction(icon: 15, label: "Ranking") { navigation.open(.ranking) }
                    KokoIconAction(icon: 3, label: "My album") { navigation.open(.album) }
                }
                KokoAction(title: "Your people · \(community.friends.count) mutual", icon: 3, emphasis: false) { navigation.open(.friends("Friends")) }
                KokoField(label: "Find a conversation", value: $search)
                Text("Friends at the table").font(.custom("AvenirNext-Bold", size: 22))
                let friendsRooms = community.rooms.filter { community.friends.contains($0.hostMemberID) }
                if friendsRooms.isEmpty {
                    KokoEmpty(title: "There's a seat for someone", detail: "Rooms from your sample mutual connections appear here.", art: 0)
                } else { ForEach(friendsRooms) { KokoRoomCard(room: $0) } }
                HStack { Text("Your conversations").font(.custom("AvenirNext-Bold", size: 22)); Spacer(); if !community.conversations.isEmpty { KokoIconAction(icon: 6, label: "Clear conversations") { confirmClear = true } } }
                if filtered.isEmpty {
                    KokoEmpty(title: search.isEmpty ? "Every friendship starts somewhere" : "No matching conversations", detail: search.isEmpty ? "Visit a profile to try a sample mutual connection. Nothing is sent to another person." : "Try another name or phrase.")
                    KokoAction(title: "Find your people", icon: 4) { navigation.open(.search) }
                }
                ForEach(filtered) { conversation in
                    KokoMenuRow(title: community.member(conversation.correspondentID)?.publicName ?? "Conversation", detail: conversation.entries.last.map { $0.messageText.isEmpty && $0.attachmentPhotoKey != nil ? "Photo from the collection" : $0.messageText } ?? (conversation.compositionDraft.isEmpty ? "A new local conversation" : "Draft: " + conversation.compositionDraft), icon: 2) {
                        community.update { journal in if let index = journal.privateConversations.firstIndex(where: { $0.id == conversation.id }) { journal.privateConversations[index].unreadEntries = 0 } }
                        navigation.open(.conversation(conversation.correspondentID))
                    }
                }
            }
            if confirmClear {
                KokoModal(title: "Clear your local conversations?", dismiss: { confirmClear = false }) {
                    Text("This removes all conversation entries and drafts from this device. Your friendships stay.")
                    KokoAction(title: "Clear conversations") { community.update { $0.privateConversations = [] }; confirmClear = false }
                    KokoAction(title: "Keep them", emphasis: false) { confirmClear = false }
                }
            }
        }
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
            KokoPage(title: community.member(memberID)?.publicName ?? "Conversation", subtitle: "LOCAL CONVERSATION · NO REMOTE DELIVERY", back: navigation.back) {
                HStack {
                    KokoAction(title: "Video preview", icon: 0) { navigation.open(.call(memberID)) }
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
                                Text("Saved locally").font(.custom("AvenirNext-Medium", size: 9)).foregroundStyle(KokoInk.secondary)
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
                    KokoAction(title: "Save message locally", icon: 12) { if community.sendMessage(draft, memberID: memberID, photoKey: attachment) { draft = ""; attachment = nil } }
                }
            }
            if showAttachmentPicker {
                KokoModal(title: "Choose a photo", dismiss: { showAttachmentPicker = false }) {
                    KokoCollectionPhotoPicker(selectedPhotoKey: $attachment)
                    KokoAction(title: "Attach selection") { guard attachment != nil else { community.notice = "Choose a photo first."; return }; showAttachmentPicker = false }
                    LocalPreviewNote(text: "COLLECTION PHOTOS · SAVED ON THIS DEVICE")
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
                KokoModal(title: "Clear this local chat?", dismiss: { showClear = false }) {
                    Text("Messages and the saved draft will be removed from this device.")
                    KokoAction(title: "Clear chat") { community.update { $0.privateConversations.removeAll { $0.correspondentID == memberID } }; draft = ""; attachment = nil; showClear = false }
                }
            }
        }.onAppear { draft = community.conversation(for: memberID)?.compositionDraft ?? "" }
            .onDisappear { if !draft.isEmpty { community.saveDraft(draft, memberID: memberID) } }
    }
}

struct KokoCallPreview: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var camera = KokoLocalCamera()
    let memberID: String
    @State private var micEnabled = true
    @State private var phase = "Ready"
    var body: some View {
        KokoPage(title: "A face-to-face hello", back: navigation.back) {
            if camera.active { KokoCameraSurface(session: camera.pipeline.captureSession).frame(height: 290).clipped() }
            else { Artwork(sheet: .scenes, tile: 1).frame(height: 245) }
            if let member = community.member(memberID) {
                HStack { Artwork(sheet: .collection, tile: member.portraitTile).frame(width: 90, height: 90); VStack(alignment: .leading, spacing: 6) { Text(member.publicName).font(.custom("AvenirNext-Bold", size: 24)); Text(phase).foregroundStyle(KokoInk.secondary) } }
            }
            LocalPreviewNote(text: "LOCAL CAMERA PREVIEW · NO CALL OR REMOTE TRANSMISSION")
            Text(camera.explanation).font(.custom("AvenirNext-Regular", size: 13))
            KokoToggleRow(title: "Microphone preview", enabled: $micEnabled)
            KokoAction(title: camera.active ? "Turn camera off" : (camera.requesting ? "Opening camera…" : "Preview my camera"), icon: 0) { if camera.active { camera.stop() } else { camera.start() } }
            KokoAction(title: camera.front ? "Camera: front · switch" : "Camera: back · switch", icon: 0, emphasis: false) { camera.flip() }
            KokoAction(title: "Preview connection request", icon: 12) {
                guard community.friends.contains(memberID) else { community.notice = "Enable a sample mutual connection from this profile first."; return }
                phase = "Waiting preview · no recipient contacted"
            }
            KokoAction(title: "End preview", emphasis: false) { navigation.back() }
        }.onDisappear { camera.stop() }
            .onChange(of: scenePhase) { phase in
                if phase == .background || (phase == .inactive && !camera.requesting) { camera.stop() }
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
        KokoPage(title: "Little updates", back: navigation.back) {
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
