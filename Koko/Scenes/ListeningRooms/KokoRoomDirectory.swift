import SwiftUI
import PhotosUI

struct KokoRoomDirectory: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @State private var topic = "All"
    @State private var audience = "Voice rooms"
    @State private var category = "For you"
    @State private var search = ""
    private var filtered: [HostedConversationRoom] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return community.rooms.filter { room in
            !room.isVideoStage
                && (topic == "All" || room.conversationTopic == topic)
                && (audience == "Voice rooms" || community.following.contains(room.hostMemberID))
                && (query.isEmpty || (room.roomTitle + " " + room.conversationTopic + " "
                    + (community.member(room.hostMemberID)?.publicName ?? "")).localizedCaseInsensitiveContains(query))
        }
    }
    private func selectCategory(_ selected: String) {
        category = selected
        if selected == "Following" {
            audience = "Following"
            topic = "All"
        } else if selected == "For you" {
            audience = "Voice rooms"
            topic = "All"
        } else {
            audience = "Voice rooms"
            topic = selected
        }
    }
    var body: some View {
        KokoPage {
            HStack(spacing: 12) {
                KokoSearchField(prompt: "Search voice rooms", query: $search)
                Button { navigation.open(.createRoom(false)) } label: {
                    Image("KokoStartVoiceRoom").resizable().scaledToFit()
                        .frame(width: 52, height: 52)
                }
                .buttonStyle(KokoPressStyle())
                .accessibilityLabel("Start a voice room")
            }
            KokoVoiceCategoryRail(selection: category, select: selectCategory)
            KokoStudioEntry()
            VStack(alignment: .leading, spacing: 4) {
                Text("Find your conversation")
                    .font(KokoTypography.heading(size: 23, relativeTo: .title2))
                Text("Voice room previews · pick a topic you love")
                    .font(KokoTypography.medium(size: 12, relativeTo: .caption))
                    .foregroundStyle(KokoInk.secondary)
            }
            LazyVStack(spacing: 14) {
                ForEach(filtered) { room in KokoVoiceRoomCard(room: room) }
            }
            if filtered.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Your next conversation starts here")
                        .font(KokoTypography.emphasis(size: 18))
                    Text("Try another topic, or make room for one of your own.")
                        .font(KokoTypography.medium(size: 13))
                        .foregroundStyle(KokoInk.secondary)
                    Button("Start a voice room →") { navigation.open(.createRoom(false)) }
                        .font(KokoTypography.heading(size: 14))
                        .foregroundStyle(KokoInk.accent)
                        .frame(minHeight: 44)
                        .buttonStyle(KokoPressStyle())
                }
                .padding(.vertical, 20)
            }
            KokoConnectionEntry(title: "Need something to talk about?", detail: "Turn a question into a voice room.",
                                artwork: "KokoConversationDeckObject") { navigation.open(.conversationStarters(nil)) }
            HStack {
                Button("Room ranking →") { navigation.open(.ranking) }
                Spacer(minLength: 12)
                Button("Start a room →") { navigation.open(.createRoom(false)) }
            }
            .font(KokoTypography.emphasis(size: 13))
            .foregroundStyle(KokoInk.accent)
            .buttonStyle(KokoPressStyle())
            .frame(minHeight: 44)
        }
    }
}

struct KokoVoiceRoomCard: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @ScaledMetric(relativeTo: .body) private var cardHeight: CGFloat = 172
    let room: HostedConversationRoom
    private var host: CommunityMember? { community.member(room.hostMemberID) }
    var body: some View {
        Group {
            GeometryReader { bounds in
                let portraitWidth = bounds.size.width * 0.378
                let informationWidth = bounds.size.width - portraitWidth
                HStack(spacing: 0) {
                    Group {
                        Button { navigation.open(.room(room.id)) } label: {
                            KokoRoomCoverPhoto(room: room)
                        }.buttonStyle(KokoPressStyle())
                    }
                    .frame(width: portraitWidth, height: bounds.size.height)
                    .clipped()
                    VStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image("KokoVoiceSessionWave").resizable().scaledToFit()
                                    .frame(width: 22, height: 18)
                                    .modifier(KokoRoomSignalBreathing())
                                    .accessibilityHidden(true)
                                (Text("VOICE · ") + Text(LocalizedStringKey(room.conversationTopic)))
                                    .font(KokoTypography.emphasis(size: 10, relativeTo: .caption))
                                    .foregroundStyle(KokoInk.accent)
                                    .lineLimit(1).minimumScaleFactor(0.8)
                            }
                            Button { navigation.open(.room(room.id)) } label: { Text(room.roomTitle) }.buttonStyle(KokoPressStyle())
                                .font(KokoTypography.heading(size: 18, relativeTo: .headline))
                                .lineLimit(2).minimumScaleFactor(0.85)
                                .frame(maxWidth: .infinity, minHeight: 46, alignment: .topLeading)
                            KokoProfileLink(memberID: room.hostMemberID) { Text("Hosted by \(host?.publicName ?? "Koko")").frame(minHeight: 44) }
                                .font(KokoTypography.medium(size: 11, relativeTo: .caption))
                                .foregroundStyle(KokoInk.secondary)
                                .lineLimit(1).minimumScaleFactor(0.85)
                        }
                        .foregroundStyle(KokoInk.primary)
                        .padding(.horizontal, 14)
                        .frame(width: informationWidth, height: bounds.size.height * 0.73, alignment: .leading)
                        Button { navigation.open(.room(room.id)) } label: { HStack(spacing: 8) {
                            Text("\(room.seatLimit) seats")
                                .font(KokoTypography.medium(size: 10, relativeTo: .caption))
                            Spacer(minLength: 0)
                            Text("Join room →")
                                .font(KokoTypography.heading(size: 12, relativeTo: .caption))
                        }
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .foregroundStyle(KokoInk.onMint)
                        .padding(.horizontal, 14)
                        .frame(width: informationWidth, height: bounds.size.height * 0.27)
                        }.buttonStyle(KokoPressStyle())
                    }
                }
            }
            .frame(height: cardHeight)
            .background { Image("KokoVoiceSessionCard").resizable().accessibilityHidden(true) }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(KokoPressStyle())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Voice room preview, \(room.roomTitle), \(room.conversationTopic), hosted by \(host?.publicName ?? "Koko"), \(room.seatLimit) seats")
        .accessibilityHint("Opens the room; microphone stays off until you choose to enable it")
    }
}

private struct KokoVoiceCategoryRail: View {
    let selection: String
    let select: (String) -> Void
    private let categories = ["For you", "Following", "Conversation", "Music", "Creative", "After hours"]
    private let columns = Array(repeating: GridItem(.flexible(minimum: 0), spacing: 8), count: 3)
    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(categories, id: \.self) { category in
                Button { select(category) } label: {
                    Text(LocalizedStringKey(category))
                        .font(KokoTypography.emphasis(size: 12, relativeTo: .caption))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(selection == category ? KokoInk.onMint : KokoInk.secondary)
                        .padding(.horizontal, 4)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background {
                            if selection == category {
                                Image("KokoVoiceTopicSelection").resizable().accessibilityHidden(true)
                            }
                        }
                }
                .buttonStyle(KokoPressStyle())
                .accessibilityAddTraits(selection == category ? .isSelected : [])
            }
        }
    }
}

struct KokoRoomComposer: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @Environment(\.kokoScreenInsets) private var screenInsets
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var textSize
    let videoStage: Bool
    @State private var roomTitle = ""
    @State private var conversationPrompt = ""
    @State private var audienceGoal = "20"
    @State private var topic = "Conversation"
    @State private var seats = "6"
    @State private var publicRoom = true
    @State private var coverSelection: PhotosPickerItem?
    @State private var showingCoverLibrary = false
    @State private var roomCoverJPEG: Data?
    @State private var importingCover = false
    @State private var showingCoverCamera = false
    @State private var checkingCamera = false
    @State private var cameraHelp: KokoCapturePermission.Decision?
    @State private var coverRevision = UUID()
    @State private var permissionRevision = UUID()
    @State private var isVisible = false
    @FocusState private var focusedField: RoomDraftField?
    private enum RoomDraftField: Hashable { case title, prompt, audience }

    init(videoStage: Bool, starter: ConversationStarter? = nil) {
        self.videoStage = videoStage
        _roomTitle = State(initialValue: starter.map { KokoCopy.text($0.roomName) } ?? "")
        _conversationPrompt = State(initialValue: starter.map { KokoCopy.text($0.question) } ?? "")
        _topic = State(initialValue: starter?.topic ?? "Conversation")
    }
    private var coverArtwork: String { videoStage ? "KokoLiveCoverInvitation" : "KokoVoiceCoverInvitation" }
    private var coverBusy: Bool { importingCover || checkingCamera }

    var body: some View {
        GeometryReader { viewport in
            let contentWidth = max(0, min(viewport.size.width - 40, 460))
            ZStack {
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Button { navigation.back() } label: {
                            Artwork(sheet: .navigation, tile: 5).frame(width: 24, height: 24)
                                .frame(width: 44, height: 44).contentShape(Rectangle())
                        }.buttonStyle(KokoPressStyle()).accessibilityLabel("Back")
                        Text(LocalizedStringKey(videoStage ? "Create a live room" : "Create a voice room"))
                            .font(KokoTypography.heading(size: 23, relativeTo: .title2))
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        Spacer(minLength: 0)
                    }.frame(width: contentWidth).padding(.top, screenInsets.top + 8).padding(.bottom, 10)
                    ScrollViewReader { scroll in
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 22) {
                                coverEditor
                                VStack(alignment: .leading, spacing: 14) {
                                    draftField(.title, label: "Room name", placeholder: "Give your room a name", text: $roomTitle)
                                    draftField(.prompt, label: "What are we talking about?", placeholder: "A question, a story, a shared interest…", text: $conversationPrompt, multiline: true)
                                }
                                VStack(alignment: .leading, spacing: 9) {
                                    fieldLabel("Room topic")
                                    LazyVGrid(columns: choiceColumns, spacing: 8) {
                                        ForEach(Array(KokoCommunity.topics.dropFirst()), id: \.self) { choice in
                                            choiceButton(choice, selected: topic == choice) { topic = choice }
                                        }
                                    }
                                }
                                if !videoStage {
                                    VStack(alignment: .leading, spacing: 9) {
                                        fieldLabel("Seats at your table")
                                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 8), count: textSize.isAccessibilitySize ? 2 : 3), spacing: 8) {
                                            ForEach(["3", "4", "6", "8", "9", "12"], id: \.self) { count in
                                                choiceButton(count, selected: seats == count) { seats = count }
                                            }
                                        }
                                    }
                                }
                                draftField(.audience, label: "Audience goal · 1–999", placeholder: "20", text: $audienceGoal, numeric: true)
                                VStack(alignment: .leading, spacing: 9) {
                                    fieldLabel("Room visibility")
                                    LazyVGrid(columns: choiceColumns, spacing: 8) {
                                        choiceButton("Public room", selected: publicRoom) { publicRoom = true }
                                        choiceButton("Private room", selected: !publicRoom) { publicRoom = false }
                                    }
                                }
                            }.frame(width: contentWidth).padding(.vertical, 12)
                                .frame(width: viewport.size.width)
                        }.scrollDismissesKeyboard(.interactively)
                            .onChange(of: focusedField) { field in
                                if let field { scroll.scrollTo(field, anchor: .center) }
                            }
                    }
                    VStack(spacing: 4) {
                        if focusedField != nil {
                            Button("Done") { focusedField = nil }
                                .font(KokoTypography.emphasis(size: 13))
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .trailing)
                                .buttonStyle(KokoPressStyle())
                        }
                        Button(action: createRoom) {
                            Text(LocalizedStringKey(importingCover ? "Preparing photo…" : "Open my room"))
                                .font(KokoTypography.heading(size: 16))
                                .foregroundStyle(KokoInk.onMint)
                                .padding(.horizontal, 18).padding(.vertical, 15)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(controlSurface(selected: true))
                        }.buttonStyle(KokoPressStyle()).disabled(coverBusy)
                    }.frame(width: contentWidth).padding(.top, 10)
                        .padding(.bottom, focusedField == nil ? screenInsets.bottom + 12 : 8)
                }.frame(width: viewport.size.width, height: viewport.size.height)
                    .background {
                        Image("KokoProfileEditorBackdrop").resizable().scaledToFill()
                            .frame(width: viewport.size.width, height: viewport.size.height).clipped()
                            .accessibilityHidden(true)
                    }
                    .disabled(showingCoverCamera || cameraHelp != nil)
                    .accessibilityHidden(showingCoverCamera || cameraHelp != nil)
                if let decision = cameraHelp {
                    KokoModal(title: "Camera unavailable", dismiss: { cameraHelp = nil }) {
                        Text(LocalizedStringKey(decision == .restricted ? "Camera access is restricted on this device." : "Camera access is unavailable. You can choose a photo instead or review access in Settings."))
                        if decision == .deniedPreviously { KokoDeviceSettingsAction() }
                        KokoAction(title: "Not now", emphasis: false) { cameraHelp = nil }
                    }
                }
                if showingCoverCamera {
                    KokoPortraitCameraPage(title: "Room cover", subtitle: "A photo for your room", returnTitle: "Back to room", close: { showingCoverCamera = false }) { jpeg in
                        coverRevision = UUID(); coverSelection = nil; importingCover = false
                        roomCoverJPEG = jpeg; showingCoverCamera = false
                    }
                }
            }.frame(width: viewport.size.width, height: viewport.size.height)
        }.foregroundStyle(KokoInk.primary).tint(KokoInk.accent)
            .onAppear { isVisible = true }
            .onDisappear {
                isVisible = false; coverRevision = UUID(); permissionRevision = UUID()
                checkingCamera = false; importingCover = false
            }
            .onChange(of: coverSelection) { selection in importCover(selection) }
            .onChange(of: scenePhase) { phase in
                if phase == .background { permissionRevision = UUID(); checkingCamera = false; cameraHelp = nil }
            }
    }

    private var coverEditor: some View {
        let layout = textSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(alignment: .center, spacing: 16))
        return layout {
            Group {
                if let data = roomCoverJPEG, let image = UIImage(data: data) { KokoPortraitPhoto(image: image) }
                else { Image(coverArtwork).resizable().scaledToFill() }
            }.frame(width: 116, height: 132).clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityLabel("Room cover")
            VStack(alignment: .leading, spacing: 4) {
                Text("Room cover").font(KokoTypography.heading(size: 17))
                Text("Make it your room.").font(KokoTypography.body(size: 12)).foregroundStyle(KokoInk.secondary)
                Button { showingCoverLibrary = true } label: {
                    coverAction("Choose photo", artwork: "KokoProfilePhotoLibrary")
                }.buttonStyle(KokoPressStyle()).disabled(coverBusy)
                    .photosPicker(isPresented: $showingCoverLibrary, selection: $coverSelection, matching: .images, photoLibrary: .shared())
                Button(action: requestCoverCamera) {
                    coverAction("Take photo", artwork: "KokoProfilePortraitCamera")
                }.buttonStyle(KokoPressStyle()).disabled(coverBusy)
                if roomCoverJPEG != nil {
                    Button("Remove photo") {
                        coverRevision = UUID(); coverSelection = nil; roomCoverJPEG = nil; importingCover = false
                    }.font(KokoTypography.medium(size: 12)).foregroundStyle(KokoInk.secondary)
                        .frame(minHeight: 44).buttonStyle(KokoPressStyle()).disabled(coverBusy)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private func coverAction(_ title: String, artwork: String) -> some View {
        HStack(spacing: 8) {
            Image(artwork).resizable().scaledToFit().frame(width: 24, height: 24).accessibilityHidden(true)
            Text(LocalizedStringKey(title)).font(KokoTypography.emphasis(size: 13))
                .fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
    }
    private var choiceColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 0), spacing: 8), count: textSize.isAccessibilitySize ? 1 : 2)
    }
    private func controlSurface(selected: Bool = false) -> some View {
        Image(selected ? "KokoProfileChoiceActive" : "KokoProfileFieldSurface").resizable().accessibilityHidden(true)
    }
    private func fieldLabel(_ label: String) -> some View {
        Text(LocalizedStringKey(label)).font(KokoTypography.emphasis(size: 12)).foregroundStyle(KokoInk.secondary)
    }
    private func choiceButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button { focusedField = nil; action() } label: {
            Text(LocalizedStringKey(title)).font(KokoTypography.emphasis(size: 13))
                .foregroundStyle(selected ? KokoInk.onMint : KokoInk.primary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 10).padding(.vertical, 12).frame(maxWidth: .infinity, minHeight: 46)
                .background(controlSurface(selected: selected))
        }.buttonStyle(KokoPressStyle()).accessibilityAddTraits(selected ? .isSelected : [])
    }
    private func draftField(_ field: RoomDraftField, label: String, placeholder: String, text: Binding<String>, multiline: Bool = false, numeric: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel(label)
            TextField(label, text: text, prompt: Text(LocalizedStringKey(placeholder)).foregroundColor(KokoInk.secondary), axis: multiline ? .vertical : .horizontal)
                .font(KokoTypography.medium(size: 15)).textFieldStyle(.plain)
                .keyboardType(numeric ? .numberPad : .default).autocorrectionDisabled(numeric)
                .focused($focusedField, equals: field).submitLabel(.done).onSubmit { focusedField = nil }
                .frame(minWidth: 0, maxWidth: .infinity)
                .padding(.horizontal, 15).padding(.vertical, 13)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: multiline ? 76 : 50)
                .background(controlSurface())
                .accessibilityLabel(Text(LocalizedStringKey(label)))
        }.id(field)
    }
    private func importCover(_ selection: PhotosPickerItem?) {
        guard let selection else { return }
        let revision = UUID(); coverRevision = revision; importingCover = true
        let memberID = community.myID
        Task {
            do {
                guard let data = try await selection.loadTransferable(type: Data.self) else { throw KokoPortraitFiles.PortraitFailure.unreadable }
                let jpeg = try await Task.detached(priority: .userInitiated) { try KokoPortraitFiles.preparedJPEG(from: data) }.value
                guard isVisible, coverRevision == revision, community.myID == memberID else { return }
                roomCoverJPEG = jpeg; importingCover = false
            } catch {
                guard isVisible, coverRevision == revision, community.myID == memberID else { return }
                importingCover = false
                community.notice = "This photo couldn't be imported. Try another photo, or take a new one."
            }
        }
    }
    private func requestCoverCamera() {
        guard !coverBusy else { return }
        focusedField = nil; cameraHelp = nil; checkingCamera = true
        let attempt = UUID(); permissionRevision = attempt
        let memberID = community.myID
        Task {
            guard isVisible, permissionRevision == attempt, community.myID == memberID else { return }
            let decision = await KokoCapturePermission.cameraDecision()
            guard isVisible, permissionRevision == attempt, community.myID == memberID else { return }
            checkingCamera = false
            switch decision {
            case .allowed: showingCoverCamera = true
            case .declinedNow: break
            case .deniedPreviously, .restricted: cameraHelp = decision
            }
        }
    }
    private func createRoom() {
        guard !coverBusy, community.currentMember != nil else { return }
        focusedField = nil
        let title = roomTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= 50, conversationPrompt.count <= 240,
              let audience = Int(audienceGoal), (1...999).contains(audience) else {
            community.notice = "Add a room name up to 50 characters, a description up to 240 characters, and an audience goal from 1 to 999."; return
        }
        let room = HostedConversationRoom(id: UUID().uuidString, roomTitle: title, conversationPrompt: conversationPrompt,
            hostMemberID: community.myID, conversationTopic: topic, seatLimit: Int(seats) ?? 6,
            isPublicRoom: publicRoom, isVideoStage: videoStage, artworkTile: videoStage ? 1 : 0,
            audienceGoal: audience, seatAssignments: [0: community.myID], mutedSeatNumbers: [0], roomCoverJPEG: roomCoverJPEG)
        if community.saveRoom(room, creating: true) { navigation.back(); navigation.open(.room(room.id)) }
    }
}
