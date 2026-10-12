import SwiftUI
import AVFoundation

struct KokoListeningRoomView: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.kokoScreenInsets) private var screenInsets
    @StateObject private var music = KokoRoomMusicPlayer()
    @StateObject private var voiceActivity = KokoRoomStageActivity()
    @StateObject private var roomDemo = KokoRoomDemoSession()
    let roomID: String
    @State private var panel: String?
    @State private var roomMessage = ""
    @State private var selectedGift = "green-rose"
    @State private var giftQuantity = "1"
    @State private var selectedSeat: Int?
    @State private var showSafety = false
    @State private var roomNote = ""
    private var room: HostedConversationRoom? { community.room(roomID) }
    private var isHost: Bool { room?.hostMemberID == community.myID }
    var body: some View {
        ZStack {
            if let room {
                let stageRoom = roomDemo.stageRoom(room, in: community)
                if room.isVideoStage {
                    KokoLiveRoomStage(
                        room: stageRoom,
                        videoAsset: liveVideoAsset,
                        audience: roomDemo.audience(in: community),
                        message: $roomMessage,
                        onBack: { panel = "Leave this room?" },
                        onSendMessage: { message in sendRoomMessage(message) },
                        onOpenPanel: { panel = $0 }
                    )
                } else {
                    voiceStage(stageRoom)
                }
                if let panel { roomPanel(panel, room: room) }
                if showSafety { KokoSafetyPanel(reportedContentID: room.id, memberID: room.hostMemberID) { showSafety = false; navigation.back() } }
            } else { KokoPage(title: "Room unavailable", back: navigation.back) { KokoEmpty(title: "This door is closed", detail: "It may have been removed or hidden on this device.") } }
        }.onDisappear { music.stop(); roomDemo.pause() }
            .onChange(of: scenePhase) { phase in if phase != .active { music.stop(); roomDemo.pause() } }
            .task(id: roomID + (scenePhase == .active ? "-active" : "-paused")) {
                guard scenePhase == .active, let room else { return }
                await roomDemo.run(room: room, community: community)
            }
    }
    private var liveVideoAsset: CommunityMediaAsset? {
        // The stage must play the same recording whose first frame is on the room card.
        KokoMediaLibrary.liveRoomPreview(for: roomID)
    }
    private func roomTool(_ icon: Int, _ label: String, _ destination: String) -> some View {
        Button { panel = destination } label: {
            HStack(spacing: 7) { Artwork(sheet: .navigation, tile: icon).frame(width: 22, height: 22); Text(LocalizedStringKey(label)).font(KokoTypography.emphasis(size: 11)) }.frame(maxWidth: .infinity).frame(minHeight: 44).background(KokoControlSurface())
        }.buttonStyle(KokoPressStyle())
    }
    private func voiceStage(_ room: HostedConversationRoom) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                KokoIconAction(icon: 5, label: "Leave room") { panel = "Leave this room?" }
                if room.roomCoverJPEG != nil {
                    KokoRoomCoverPhoto(room: room).frame(width: 44, height: 44)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("VOICE ROOM · " + room.conversationTopic.uppercased())
                        .font(KokoTypography.heading(size: 10)).tracking(1.3).foregroundStyle(KokoInk.accent)
                    Text(room.roomTitle).font(KokoTypography.heading(size: 21)).lineLimit(2)
                }
                Spacer(minLength: 0)
                KokoIconAction(icon: 11, label: "Room options") { panel = "Around this room" }
            }.padding(.horizontal, 18).padding(.top, screenInsets.top + 8).padding(.bottom, 12)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    if isHost {
                        if let plan = community.activeConversationPlan(in: room.id) {
                            KokoStudioPaper {
                                Text("Hosting cues").font(KokoTypography.emphasis(size: 13))
                                Text(verbatim: plan.orderedPrompts[plan.activePromptIndex]).font(KokoTypography.heading(size: 21))
                                KokoStudioAction(title: "Open cue board") { navigation.open(.conversationPlan(plan.id, room.id)) }
                            }
                        } else {
                            KokoStudioAction(title: "Arrange this conversation") { navigation.open(.conversationStudio(room.id)) }
                        }
                    }
                    HStack(spacing: 10) {
                        if let host = community.member(room.hostMemberID) {
                            Button { navigation.open(.profile(host.id)) } label: {
                                HStack(spacing: 9) {
                                    KokoMemberPortrait(member: host).frame(width: 36, height: 36).clipShape(Circle())
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(host.publicName).font(KokoTypography.emphasis(size: 13))
                                        Text("Room host").font(KokoTypography.body(size: 10)).foregroundStyle(KokoInk.secondary)
                                    }
                                }
                            }.buttonStyle(.plain)
                        }
                        Spacer()
                        if !isHost {
                            Button(community.following.contains(room.hostMemberID) ? "Following" : "+ Follow") { community.toggleFollow(room.hostMemberID) }
                                .font(KokoTypography.heading(size: 12)).padding(.horizontal, 18).padding(.vertical, 10)
                                .background(ArtworkSurface(tile: 3)).foregroundStyle(KokoInk.onMint).buttonStyle(.plain)
                        }
                    }
                    HStack(spacing: 8) {
                        Artwork(sheet: .liveControls, tile: 2).frame(width: 23, height: 23)
                            .modifier(KokoRoomSignalBreathing())
                        Text("Voice room").font(KokoTypography.emphasis(size: 12)).foregroundStyle(KokoInk.accent)
                        Spacer(minLength: 0)
                        KokoRoomAudienceButton(members: roomDemo.audience(in: community)) { panel = "Room audience" }
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                        ForEach(0..<room.seatLimit, id: \.self) { position in seatView(position, room: room) }
                    }.padding(.vertical, 2)
                }.padding(.horizontal, 18).padding(.bottom, 12)
            }.scrollDismissesKeyboard(.interactively)
            voiceConversationDeck(room)
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    roomTool(13, "Join mic", "Voice connection")
                    roomTool(14, "Music", "Room music")
                }
                KokoLiveRoomComposer(message: $roomMessage, send: { sendRoomMessage(roomMessage) }, gift: { panel = "Send a little something" })
            }.padding(.horizontal, 18).padding(.top, 12).padding(.bottom, screenInsets.bottom + 8)
                .background(KokoInk.canvas.opacity(0.92))
        }
        .foregroundStyle(KokoInk.primary)
        .background {
            GeometryReader { bounds in
                Image("KokoVoiceOrbitStage").resizable().scaledToFill()
                    .frame(width: bounds.size.width, height: bounds.size.height).clipped()
            }.allowsHitTesting(false).accessibilityHidden(true)
        }
        .onAppear { voiceActivity.begin(room.roomConversation) }
        .onDisappear { voiceActivity.reset() }
        .onChange(of: room.roomConversation) { entries in
            if scenePhase == .active { voiceActivity.receive(entries) }
        }
        .onChange(of: room.id) { _ in voiceActivity.begin(room.roomConversation) }
        .onChange(of: scenePhase) { phase in
            if phase == .active { voiceActivity.begin(room.roomConversation) }
            else { voiceActivity.reset() }
        }
    }

    /// Chat stays visible beneath the scrolling microphone seats, including eight-seat rooms.
    /// Gift arrivals temporarily float over this interaction area, never the seat controls.
    private func voiceConversationDeck(_ room: HostedConversationRoom) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text("Room chat").font(KokoTypography.heading(size: 15))
                Spacer()
                Button("Quick hello") { panel = "Quick hellos" }
                    .font(KokoTypography.emphasis(size: 11)).frame(minHeight: 44).buttonStyle(.plain)
            }
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    KokoRoomChatLog(entries: Array(room.roomConversation.suffix(30)), showsEmptyState: false, compact: true)
                        .id("voice-chat-bottom")
                }.frame(height: 128)
                    .onChange(of: room.roomConversation.last?.id) { _ in
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                            proxy.scrollTo("voice-chat-bottom", anchor: .bottom)
                        }
                    }
                    .onAppear { proxy.scrollTo("voice-chat-bottom", anchor: .bottom) }
            }
        }
        .padding(.horizontal, 18).padding(.bottom, 6)
        .overlay(alignment: .bottom) {
            KokoRoomGiftShower(flights: voiceActivity.flights, isPlaying: scenePhase == .active)
                .frame(height: 174).padding(.horizontal, 18).accessibilityHidden(true)
        }
    }

    private func seatView(_ position: Int, room: HostedConversationRoom) -> some View {
        VStack(spacing: 4) {
            Button {
                if let memberID = room.seatAssignments[position] {
                    navigation.open(.profile(memberID))
                } else {
                    selectedSeat = position
                    panel = isHost ? "Invite a sample guest" : "Take this seat?"
                }
            } label: {
                VStack(spacing: 6) {
                    if let memberID = room.seatAssignments[position], let member = community.member(memberID) {
                        ZStack {
                            KokoMemberPortrait(member: member).frame(width: 54, height: 54).clipShape(Circle())
                            Image("KokoVoiceSeatOrbit").resizable().scaledToFit().frame(width: 82, height: 82)
                                .opacity(roomDemo.speakingMemberID == memberID ? 1 : 0.55)
                                .scaleEffect(roomDemo.speakingMemberID == memberID ? 1.04 : 0.96)
                                .animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: roomDemo.speakingMemberID)
                                .accessibilityHidden(true)
                        }.frame(height: 82)
                        Text(member.publicName).lineLimit(1)
                        Text(LocalizedStringKey(room.mutedSeatNumbers.contains(position) ? "Muted" : (roomDemo.speakingMemberID == memberID ? "Speaking" : (position == 0 ? "Host" : "On mic"))))
                            .font(KokoTypography.body(size: 9)).foregroundStyle(KokoInk.accent)
                    } else {
                        ZStack {
                            Image("KokoVoiceSeatOrbit").resizable().scaledToFit().frame(width: 82, height: 82).opacity(0.3)
                            Artwork(sheet: .navigation, tile: 13).frame(width: 26, height: 26).opacity(0.7)
                        }.frame(height: 82)
                        Text("Open mic \(position + 1)")
                        Text("Tap to join").font(KokoTypography.body(size: 9)).foregroundStyle(KokoInk.secondary)
                    }
                }.font(KokoTypography.emphasis(size: 11)).frame(maxWidth: .infinity).contentShape(Rectangle())
            }.buttonStyle(KokoPressStyle())
            if let memberID = room.seatAssignments[position], memberID == community.myID || isHost || room.moderatorMemberIDs.contains(community.myID) {
                Button("At this seat") { selectedSeat = position; panel = "At this seat" }
                    .font(KokoTypography.medium(size: 10)).frame(minHeight: 44).buttonStyle(KokoPressStyle())
            }
        }
    }
    @discardableResult
    private func sendRoomMessage(_ message: String) -> Bool {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var room else { return false }
        room.roomConversation.append(.init(authorMemberID: community.myID, messageText: String(trimmed.prefix(500))))
        return community.saveRoom(room)
    }
    @ViewBuilder private func roomPanel(_ title: String, room: HostedConversationRoom) -> some View {
        KokoModal(title: title, presentation: .selection, dismiss: { panel = nil }) {
            switch title {
            case "Send a little something":
                Text("\(community.coinBalance) coins available").font(KokoTypography.medium(size: 13))
                Text("Eight room gifts · paid with Koko coins from the Apple wallet")
                    .font(KokoTypography.body(size: 12))
                    .foregroundStyle(KokoInk.secondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
                    ForEach(KokoCommunity.keepsakes) { gift in
                        Button { selectedGift = gift.id } label: {
                            VStack { Artwork(sheet: .collection, tile: gift.artworkTile).frame(height: 72); Text(LocalizedStringKey(gift.keepsakeName)).font(KokoTypography.emphasis(size: 12)); Text("\(gift.coinPrice) coins").font(KokoTypography.body(size: 11)) }.padding(10).frame(maxWidth: .infinity).background(KokoControlSurface(highlighted: selectedGift == gift.id)).foregroundStyle(selectedGift == gift.id ? KokoInk.canvas : KokoInk.primary)
                        }.buttonStyle(.plain)
                    }
                }
                KokoChoiceRail(choices: ["1", "3", "5", "10"], selection: $giftQuantity)
                if let gift = KokoCommunity.keepsakes.first(where: { $0.id == selectedGift }) {
                    KokoAction(title: "Review gift · \(gift.coinPrice * (Int(giftQuantity) ?? 1)) coins", icon: 8) {
                        community.requestKeepsake(gift, quantity: Int(giftQuantity) ?? 1, roomID: room.id); panel = nil
                    }
                }
                KokoAction(title: "Buy coins in wallet", emphasis: false) { panel = nil; navigation.open(.wallet) }
            case "Invite a sample guest":
                Text("Choose a sample participant for this seat. This is room setup; no invitation is sent.")
                let candidates = community.members.filter { !room.seatAssignments.values.contains($0.id) }
                ForEach(candidates) { member in
                    VStack(spacing: 8) {
                        KokoMemberRow(member: member)
                        KokoAction(title: "Choose", emphasis: false) {
                            guard let seat = selectedSeat, room.seatAssignments[seat] == nil else { return }
                            var updated = room; updated.seatAssignments[seat] = member.id
                            _ = community.saveRoom(updated); panel = nil
                        }
                    }
                }
                if candidates.isEmpty { Text("Every available sample guest already has a seat.") }
            case "Take this seat?":
                Text("Check your microphone permission and prepare a seat request. Nothing is sent to the host.")
                KokoAction(title: "Prepare seat \((selectedSeat ?? 0) + 1)", icon: 13) {
                    let seat = selectedSeat; panel = nil; music.stop()
                    navigation.open(.roomConnection(roomID, seat))
                }
            case "At this seat":
                if let seat = selectedSeat, let memberID = room.seatAssignments[seat] {
                    if let member = community.member(memberID) { KokoMemberRow(member: member) }
                    if memberID == community.myID || isHost || room.moderatorMemberIDs.contains(community.myID) {
                        KokoAction(title: memberID == community.myID ? "Manage my microphone" : (room.mutedSeatNumbers.contains(seat) ? "Unmute seat" : "Mute seat"), icon: 13) {
                            if memberID == community.myID {
                                panel = nil; music.stop(); navigation.open(.roomConnection(roomID, seat)); return
                            }
                            var updated = room
                            if updated.mutedSeatNumbers.contains(seat) { updated.mutedSeatNumbers.remove(seat) } else { updated.mutedSeatNumbers.insert(seat) }
                            _ = community.saveRoom(updated); panel = nil
                        }
                        if seat != 0 {
                            KokoAction(title: memberID == community.myID ? "Leave my seat" : "Remove from seat", emphasis: false) { var updated = room; updated.seatAssignments.removeValue(forKey: seat); updated.mutedSeatNumbers.remove(seat); _ = community.saveRoom(updated); panel = nil }
                        }
                    }
                    if isHost, memberID != community.myID {
                        KokoAction(title: room.moderatorMemberIDs.contains(memberID) ? "Remove moderator" : "Make room moderator", emphasis: false) {
                            var updated = room
                            if updated.moderatorMemberIDs.contains(memberID) { updated.moderatorMemberIDs.remove(memberID) } else { updated.moderatorMemberIDs.insert(memberID) }
                            _ = community.saveRoom(updated); panel = nil
                        }
                    }
                }
            case "Room audience":
                Text("\(roomDemo.audience(in: community).count) online").font(KokoTypography.heading(size: 20))
                ForEach(roomDemo.audience(in: community)) { member in
                    Button { panel = nil; navigation.open(.profile(member.id)) } label: {
                        HStack(spacing: 12) {
                            KokoMemberPortrait(member: member).frame(width: 42, height: 42).clipShape(Circle())
                            VStack(alignment: .leading, spacing: 4) {
                                Text(member.publicName).font(KokoTypography.emphasis(size: 15))
                                Text(LocalizedStringKey(member.id == room.hostMemberID ? "Host" : (room.seatAssignments.values.contains(member.id) ? "On mic" : "Listening")))
                                    .font(KokoTypography.medium(size: 11)).foregroundStyle(KokoInk.accent)
                            }
                            Spacer()
                        }.padding(.vertical, 8).contentShape(Rectangle())
                    }.buttonStyle(KokoPressStyle())
                }
            case "Voice connection":
                Artwork(sheet: .navigation, tile: 13)
                    .frame(width: 30, height: 30)
                    .padding(18)
                    .background(KokoControlSurface())
                Text("Request a seat, check your microphone, and try the room controls. Voice and video are always free.")
                KokoAction(title: "Open connection panel", icon: 13) { panel = nil; music.stop(); navigation.open(.roomConnection(roomID, nil)) }
                if room.seatAssignments.values.contains(community.myID), !isHost { KokoAction(title: "Leave my seat", emphasis: false) { community.leaveSeat(in: roomID); panel = nil } }
            case "Room music":
                Text("Music plays on this device only. Audio files can be added later.").font(KokoTypography.body(size: 13))
                ForEach(KokoRoomMusicPlayer.tracks, id: \.self) { track in
                    KokoMenuRow(title: track, detail: music.currentTrack == track ? "Playing on this device" : "Audio placeholder", icon: 14) { music.play(track) { community.notice = $0 } }
                }
                HStack { KokoAction(title: "Quieter", emphasis: false) { music.adjustVolume(-0.1) }; Text("\(Int(music.volume * 100))%"); KokoAction(title: "Louder", emphasis: false) { music.adjustVolume(0.1) } }
                KokoAction(title: music.muted ? "Unmute music" : "Mute music", emphasis: false) { music.toggleMute() }
                KokoAction(title: "Stop music") { music.stop() }
            case "Quick hellos":
                ForEach(["Hello, happy to be here.", "What are we listening to?", "That is a lovely thought.", "Thanks for making room."], id: \.self) { phrase in KokoAction(title: phrase, emphasis: false) { sendRoomMessage(phrase); panel = nil } }
            case "Around this room":
                KokoMenuRow(title: "Room audience", icon: 3) { panel = "Room audience" }
                KokoMenuRow(title: "Room ranking", icon: 15) { panel = "Room ranking" }
                KokoMenuRow(title: "More rooms", icon: 1) { panel = "More rooms" }
                if isHost { KokoMenuRow(title: "Host's note", icon: 11) { roomNote = room.hostNote; panel = "Host's note" } }
                KokoMenuRow(title: "Report or block", icon: 11) { panel = nil; showSafety = true }
            case "Host's note":
                KokoField(label: "A note for everyone", value: $roomNote, multiline: true)
                KokoAction(title: "Save room note") { var updated = room; updated.hostNote = String(roomNote.prefix(200)); _ = community.saveRoom(updated); panel = nil }
            case "Room ranking":
                Text("Your contributions").font(KokoTypography.heading(size: 18))
                let spent = (community.journal?.walletHistory ?? []).filter { $0.entryDescription.contains(room.roomTitle) && $0.coinDelta < 0 }.reduce(0) { $0 - $1.coinDelta }
                Text("Your gifts in this room: \(spent) coins")
                Text("Other members have no recorded contributions on this device.").foregroundStyle(KokoInk.secondary)
            case "More rooms":
                ForEach(community.rooms.filter { $0.id != roomID }) { other in KokoRoomCard(room: other) }
            default:
                Text("You can return whenever you like. Your messages and gifts will be kept.")
                KokoAction(title: "Leave room") { music.stop(); community.leaveSeat(in: roomID); navigation.back() }
                KokoAction(title: "Stay a little longer", emphasis: false) { panel = nil }
            }
        }
    }
}


@MainActor
final class KokoRoomMusicPlayer: ObservableObject {
    static let tracks = ["Window seat", "Slow afternoon", "Last train home"]
    @Published private(set) var currentTrack: String?
    @Published private(set) var volume: Float = 0.5
    @Published private(set) var muted = false
    private let playback = KokoRoomMusicPlayback()
    private var playbackAttempt = UUID()
    func play(_ title: String, unavailable: @escaping @MainActor (String) -> Void) {
        let key = "koko-" + title.lowercased().replacingOccurrences(of: " ", with: "-")
        guard let url = Bundle.main.url(forResource: key, withExtension: "mp3") else { unavailable("This music file hasn't been added yet. Add \(key).mp3 to enable playback."); return }
        let attempt = UUID(); playbackAttempt = attempt; currentTrack = nil
        playback.play(url, volume: muted ? 0 : volume) { [weak self] success in
            Task { @MainActor in
                guard let self, self.playbackAttempt == attempt else { return }
                if success { self.currentTrack = title }
                else { unavailable("This audio file couldn't be played.") }
            }
        }
    }
    func adjustVolume(_ change: Float) { volume = min(1, max(0, volume + change)); playback.setVolume(muted ? 0 : volume) }
    func toggleMute() { muted.toggle(); playback.setVolume(muted ? 0 : volume) }
    func stop() { playbackAttempt = UUID(); currentTrack = nil; playback.stop() }
    deinit { playback.stop() }
}

// The player and audio-session ownership are confined to this serial queue.
private final class KokoRoomMusicPlayback: @unchecked Sendable {
    private let queue = DispatchQueue(label: "koko.room-music-playback")
    private var player: AVAudioPlayer?
    private var ownsSession = false

    func play(_ url: URL, volume: Float, completion: @escaping @Sendable (Bool) -> Void) {
        queue.async { [self] in
            stopOnQueue()
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default)
                try session.setActive(true)
                ownsSession = true
                let next = try AVAudioPlayer(contentsOf: url)
                next.volume = volume; next.numberOfLoops = -1; player = next
                let started = next.play()
                if !started { stopOnQueue() }
                completion(started)
            } catch { stopOnQueue(); completion(false) }
        }
    }
    func setVolume(_ volume: Float) { queue.async { [self] in player?.volume = volume } }
    func stop() { queue.async { [self] in stopOnQueue() } }
    private func stopOnQueue() {
        player?.stop(); player = nil
        guard ownsSession else { return }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        ownsSession = false
    }
}
