import SwiftUI
import AVFoundation

struct KokoListeningRoomView: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.kokoScreenInsets) private var screenInsets
    @StateObject private var music = KokoRoomMusicPlayer()
    let roomID: String
    @State private var panel: String?
    @State private var roomMessage = ""
    @State private var selectedGift = "green-rose"
    @State private var giftQuantity = "1"
    @State private var selectedSeat: Int?
    @State private var showSafety = false
    @State private var roomNote = ""
    private var room: ListeningRoom? { community.room(roomID) }
    private var isHost: Bool { room?.hostMemberID == community.myID }
    var body: some View {
        ZStack {
            if let room {
                if room.isVideoStage {
                    KokoLiveRoomStage(
                        room: room,
                        videoAsset: liveVideoAsset,
                        message: $roomMessage,
                        onBack: { panel = "Leave this room?" },
                        onSendMessage: { message in sendRoomMessage(message) },
                        onOpenPanel: { panel = $0 }
                    )
                } else {
                    voiceStage(room)
                }
                if let panel { roomPanel(panel, room: room) }
                if showSafety { KokoSafetyPanel(subjectKey: room.id, memberID: room.hostMemberID) { showSafety = false; navigation.back() } }
            } else { KokoPage(title: "Room unavailable", back: navigation.back) { KokoEmpty(title: "This door is closed", detail: "It may have been removed or hidden on this device.") } }
        }.onDisappear { music.stop() }
            .onChange(of: scenePhase) { phase in if phase != .active { music.stop() } }
    }
    private var liveVideoAsset: CommunityMediaAsset? {
        let videos = KokoMediaLibrary.assets.filter(\.isVideo)
        guard !videos.isEmpty else { return nil }
        let stableIndex = roomID.utf8.reduce(0) { ($0 + Int($1)) % videos.count }
        return videos[stableIndex]
    }
    private func roomTool(_ icon: Int, _ label: String, _ destination: String) -> some View {
        Button { panel = destination } label: {
            VStack(spacing: 5) { Artwork(sheet: .navigation, tile: icon).frame(width: 30, height: 30); Text(label).font(.custom("AvenirNext-DemiBold", size: 11)) }.frame(maxWidth: .infinity).padding(.vertical, 12).background(ArtworkSurface())
        }.buttonStyle(KokoPressStyle())
    }
    private func voiceStage(_ room: ListeningRoom) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                KokoIconAction(icon: 5, label: "Leave room") { panel = "Leave this room?" }
                VStack(alignment: .leading, spacing: 3) {
                    Text("VOICE ROOM · " + room.conversationTopic.uppercased())
                        .font(.custom("AvenirNext-Bold", size: 10)).tracking(1.3).foregroundStyle(KokoInk.accent)
                    Text(room.roomTitle).font(.custom("AvenirNext-Bold", size: 21)).lineLimit(2)
                }
                Spacer(minLength: 0)
                KokoIconAction(icon: 11, label: "Room options") { panel = "Around this room" }
            }.padding(.horizontal, 18).padding(.top, screenInsets.top + 8).padding(.bottom, 12)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    HStack(spacing: 10) {
                        if let host = community.member(room.hostMemberID) {
                            Button { navigation.open(.profile(host.id)) } label: {
                                HStack(spacing: 9) {
                                    KokoMemberPortrait(member: host).frame(width: 36, height: 36).clipShape(Circle())
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(host.publicName).font(.custom("AvenirNext-DemiBold", size: 13))
                                        Text("Room host").font(.custom("AvenirNext-Regular", size: 10)).foregroundStyle(KokoInk.secondary)
                                    }
                                }
                            }.buttonStyle(.plain)
                        }
                        Spacer()
                        if !isHost {
                            Button(community.following.contains(room.hostMemberID) ? "Following" : "+ Follow") { community.toggleFollow(room.hostMemberID) }
                                .font(.custom("AvenirNext-Bold", size: 12)).padding(.horizontal, 18).padding(.vertical, 10)
                                .background(ArtworkSurface(tile: 3)).foregroundStyle(KokoInk.onMint).buttonStyle(.plain)
                        }
                    }
                    HStack {
                        Artwork(sheet: .tabs, tile: 1).frame(width: 34, height: 34)
                        Text(room.conversationPrompt).font(.custom("AvenirNext-Medium", size: 13))
                        Spacer(minLength: 0)
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 20) {
                        ForEach(0..<room.seatLimit, id: \.self) { position in seatView(position, room: room) }
                    }.padding(.vertical, 8)
                    HStack {
                        Text("LOCAL PREVIEW · MICROPHONE OFF")
                            .font(.custom("AvenirNext-DemiBold", size: 9)).tracking(0.6).foregroundStyle(KokoInk.secondary)
                        Spacer()
                        Button("People") { panel = "Room audience" }.font(.custom("AvenirNext-DemiBold", size: 12)).buttonStyle(.plain)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ROOM NOTE").font(.custom("AvenirNext-Bold", size: 9)).tracking(1.5).foregroundStyle(KokoInk.accent)
                        Text(room.hostNote).font(.custom("AvenirNext-Regular", size: 12))
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(14).background(ArtworkSurface())
                    HStack { Text("Room chat").font(.custom("AvenirNext-Bold", size: 18)); Spacer(); Button("Quick hello") { panel = "Quick hellos" }.font(.custom("AvenirNext-DemiBold", size: 12)).buttonStyle(.plain) }
                    KokoRoomChatLog(entries: room.roomConversation)
                }.padding(.horizontal, 22).padding(.bottom, 20)
            }.scrollDismissesKeyboard(.interactively)
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    roomTool(13, "Join mic", "Voice connection")
                    roomTool(14, "Music", "Room music")
                    roomTool(8, "Gifts", "Send a little something")
                }
                KokoRoomComposer(message: $roomMessage, send: { sendRoomMessage(roomMessage) }, gift: { panel = "Send a little something" })
            }.padding(.horizontal, 18).padding(.top, 12).padding(.bottom, screenInsets.bottom + 8)
                .background(KokoInk.canvas.opacity(0.92))
        }
        .foregroundStyle(KokoInk.primary)
        .background(LinearGradient(colors: [KokoInk.panelRaised, KokoInk.canvas, Color(red: 0.08, green: 0.08, blue: 0.18)], startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    private func seatView(_ position: Int, room: ListeningRoom) -> some View {
        Button {
            selectedSeat = position
            panel = room.seatAssignments[position] == nil ? (isHost ? "Invite a sample guest" : "Take this seat?") : "At this seat"
        } label: {
            VStack(spacing: 6) {
                if let memberID = room.seatAssignments[position], let member = community.member(memberID) {
                    KokoMemberPortrait(member: member).frame(width: 66, height: 66).clipShape(Circle())
                    Text(member.publicName).lineLimit(1)
                    Text(room.mutedSeatNumbers.contains(position) ? "Muted" : (position == 0 ? "Host · preview" : "Guest · preview"))
                        .font(.custom("AvenirNext-Regular", size: 9)).foregroundStyle(KokoInk.accent)
                } else {
                    Artwork(sheet: .tabs, tile: 1).frame(width: 58, height: 58).opacity(0.55).frame(height: 66)
                    Text("Open mic \(position + 1)")
                    Text("Tap to join").font(.custom("AvenirNext-Regular", size: 9)).foregroundStyle(KokoInk.secondary)
                }
            }.font(.custom("AvenirNext-DemiBold", size: 11)).frame(maxWidth: .infinity).contentShape(Rectangle())
        }.buttonStyle(KokoPressStyle())
    }
    @discardableResult
    private func sendRoomMessage(_ message: String) -> Bool {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var room else { return false }
        room.roomConversation.append(.init(authorMemberID: community.myID, messageText: String(trimmed.prefix(500))))
        return community.saveRoom(room)
    }
    @ViewBuilder private func roomPanel(_ title: String, room: ListeningRoom) -> some View {
        KokoModal(title: title, dismiss: { panel = nil }) {
            switch title {
            case "Send a little something":
                Text("\(community.coinBalance) coins available").font(.custom("AvenirNext-Medium", size: 13))
                Text("Eight room gifts · paid with Koko coins from the Apple wallet")
                    .font(.custom("AvenirNext-Regular", size: 12))
                    .foregroundStyle(KokoInk.secondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
                    ForEach(KokoCommunity.keepsakes) { gift in
                        Button { selectedGift = gift.id } label: {
                            VStack { Artwork(sheet: .collection, tile: gift.artworkTile).frame(height: 72); Text(gift.keepsakeName).font(.custom("AvenirNext-DemiBold", size: 12)); Text("\(gift.tokenCost) coins").font(.custom("AvenirNext-Regular", size: 11)) }.padding(10).frame(maxWidth: .infinity).background(ArtworkSurface(tile: selectedGift == gift.id ? 3 : 2))
                        }.buttonStyle(.plain)
                    }
                }
                KokoChoiceRail(choices: ["1", "3", "5", "10"], selection: $giftQuantity)
                if let gift = KokoCommunity.keepsakes.first(where: { $0.id == selectedGift }) {
                    KokoAction(title: "Review gift · \(gift.tokenCost * (Int(giftQuantity) ?? 1)) coins", icon: 8) {
                        community.requestKeepsake(gift, quantity: Int(giftQuantity) ?? 1, roomID: room.id); panel = nil
                    }
                }
                KokoAction(title: "Buy coins in wallet", emphasis: false) { panel = nil; navigation.open(.wallet) }
            case "Invite a sample guest":
                Text("Choose a sample participant for this seat. This is local room setup; no invitation is sent.")
                let candidates = community.members.filter { !room.seatAssignments.values.contains($0.id) }
                ForEach(candidates) { member in
                    KokoAction(title: "Seat " + member.publicName, emphasis: false) {
                        guard let seat = selectedSeat, room.seatAssignments[seat] == nil else { return }
                        var updated = room; updated.seatAssignments[seat] = member.id
                        _ = community.saveRoom(updated); panel = nil
                    }
                }
                if candidates.isEmpty { Text("Every available sample guest already has a seat.") }
            case "Take this seat?":
                Text("Check your microphone permission and prepare a local seat request. Nothing is sent to the host.")
                KokoAction(title: "Prepare seat \((selectedSeat ?? 0) + 1)", icon: 13) {
                    let seat = selectedSeat; panel = nil; music.stop()
                    navigation.open(.roomConnection(roomID, seat))
                }
            case "At this seat":
                if let seat = selectedSeat, let memberID = room.seatAssignments[seat] {
                    if let member = community.member(memberID) { KokoMemberRow(member: member) }
                    if memberID == community.myID || isHost || room.moderatorMemberIDs.contains(community.myID) {
                        KokoAction(title: memberID == community.myID ? "Manage my microphone" : (room.mutedSeatNumbers.contains(seat) ? "Unmute seat locally" : "Mute seat locally"), icon: 13) {
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
                ForEach(Array(Set(room.seatAssignments.values)).sorted(), id: \.self) { memberID in if let member = community.member(memberID) { KokoMemberRow(member: member) } }
                LocalPreviewNote(text: "SAMPLE OCCUPANTS · NO REAL-TIME AUDIENCE CONNECTED")
            case "Voice connection":
                Artwork(sheet: .arrival, tile: 1).frame(height: 140)
                Text("Request a seat, check your microphone, and try the local stage controls. Voice and video are always free.")
                KokoAction(title: "Open connection panel", icon: 13) { panel = nil; music.stop(); navigation.open(.roomConnection(roomID, nil)) }
                if room.seatAssignments.values.contains(community.myID), !isHost { KokoAction(title: "Leave my seat", emphasis: false) { community.leaveSeat(in: roomID); panel = nil } }
            case "Room music":
                Text("Music plays on this device only. Audio files can be added later.").font(.custom("AvenirNext-Regular", size: 13))
                ForEach(KokoRoomMusicPlayer.tracks, id: \.self) { track in
                    KokoMenuRow(title: track, detail: music.currentTrack == track ? "Playing locally" : "Local audio placeholder", icon: 14) { music.play(track) { community.notice = $0 } }
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
                Text("Local contributions").font(.custom("AvenirNext-Bold", size: 18))
                let spent = (community.journal?.walletHistory ?? []).filter { $0.detailLine.contains(room.roomTitle) && $0.tokenChange < 0 }.reduce(0) { $0 - $1.tokenChange }
                Text("Your gifts in this room: \(spent) coins")
                Text("Other members have no recorded contributions on this device.").foregroundStyle(KokoInk.secondary)
            case "More rooms":
                ForEach(community.rooms.filter { $0.id != roomID }) { other in KokoRoomCard(room: other) }
            default:
                Text("You can return whenever you like. Your local messages and gifts will be kept.")
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
    private var player: AVAudioPlayer?
    func play(_ title: String, unavailable: (String) -> Void) {
        let key = "koko-" + title.lowercased().replacingOccurrences(of: " ", with: "-")
        guard let url = Bundle.main.url(forResource: key, withExtension: "mp3") else { unavailable("This music file hasn't been added yet. Add \(key).mp3 to enable playback."); return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url); player?.volume = muted ? 0 : volume; player?.numberOfLoops = -1
            if player?.play() == true { currentTrack = title }
        } catch { unavailable("This audio file couldn't be played.") }
    }
    func adjustVolume(_ change: Float) { volume = min(1, max(0, volume + change)); player?.volume = muted ? 0 : volume }
    func toggleMute() { muted.toggle(); player?.volume = muted ? 0 : volume }
    func stop() { player?.stop(); player = nil; currentTrack = nil; try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
}
