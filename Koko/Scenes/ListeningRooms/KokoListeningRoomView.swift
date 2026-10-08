import SwiftUI
import AVFoundation

struct KokoListeningRoomView: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @Environment(\.scenePhase) private var scenePhase
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
                KokoPage(title: room.roomTitle, subtitle: "\(room.conversationTopic.uppercased()) · LOCAL \(room.isVideoStage ? "VIDEO" : "VOICE") ROOM", back: { panel = "Leave this room?" }) {
                    ZStack(alignment: .bottomLeading) {
                        Artwork(sheet: .scenes, tile: room.artworkTile).frame(height: room.isVideoStage ? 300 : 180).frame(maxWidth: .infinity)
                        Text(room.isVideoStage ? "Video placeholder · no live broadcast" : "A little space for good company")
                            .font(.custom("AvenirNext-DemiBold", size: 12)).padding(15).background(ArtworkSurface()).padding(8)
                    }
                    HStack(spacing: 10) {
                        if let host = community.member(room.hostMemberID) {
                            Button { navigation.open(.profile(host.id)) } label: { HStack { Artwork(sheet: .collection, tile: host.portraitTile).frame(width: 44, height: 44); VStack(alignment: .leading) { Text(host.publicName).font(.custom("AvenirNext-Bold", size: 16)); Text("Your host").font(.custom("AvenirNext-Regular", size: 11)) } } }.buttonStyle(.plain)
                        }
                        Spacer()
                        if !isHost { KokoAction(title: community.following.contains(room.hostMemberID) ? "Following" : "Follow", emphasis: false) { community.toggleFollow(room.hostMemberID) }.frame(width: 110) }
                    }
                    Text(room.conversationPrompt).font(.custom("AvenirNext-DemiBold", size: 19))
                    HStack { Text("At the table · \(room.seatAssignments.count)/\(room.seatLimit)").font(.custom("AvenirNext-Bold", size: 16)); Spacer(); Button("Audience") { panel = "Room audience" }.font(.custom("AvenirNext-Medium", size: 12)).buttonStyle(.plain) }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                        ForEach(0..<room.seatLimit, id: \.self) { position in seatView(position, room: room) }
                    }
                    KokoCard(tint: 5) { Text(room.hostNote).font(.custom("AvenirNext-Regular", size: 13)) }
                    HStack(spacing: 8) {
                        roomTool(8, "Gifts", "Send a little something")
                        roomTool(13, "Connect", "Voice connection")
                        roomTool(14, "Music", "Room music")
                        roomTool(11, "More", "Around this room")
                    }
                    Text("The conversation").font(.custom("AvenirNext-Bold", size: 20))
                    if room.roomConversation.isEmpty { Text("Say the first hello. Messages stay in this local room.").foregroundStyle(KokoInk.secondary).font(.custom("AvenirNext-Regular", size: 14)) }
                    ForEach(room.roomConversation) { message in
                        KokoCard {
                            VStack(alignment: .leading, spacing: 7) {
                                Text(community.member(message.authorMemberID)?.publicName ?? "Guest").font(.custom("AvenirNext-DemiBold", size: 12))
                                Text(message.messageText).font(.custom("AvenirNext-Regular", size: 14))
                                if let tile = message.attachmentTile { Artwork(sheet: .collection, tile: tile).frame(height: 65) }
                            }
                        }
                    }
                    HStack { KokoField(label: "A thought for the room", value: $roomMessage); KokoIconAction(icon: 12, label: "Send local room message") { sendRoomMessage(roomMessage); roomMessage = "" } }
                    KokoAction(title: "Quick hellos", emphasis: false) { panel = "Quick hellos" }
                }
                if let panel { roomPanel(panel, room: room) }
                if showSafety { KokoSafetyPanel(subjectKey: room.id, memberID: room.hostMemberID) { showSafety = false; navigation.back() } }
            } else { KokoPage(title: "Room unavailable", back: navigation.back) { KokoEmpty(title: "This door is closed", detail: "It may have been removed or hidden on this device.") } }
        }.onDisappear { music.stop() }
            .onChange(of: scenePhase) { phase in if phase != .active { music.stop() } }
    }
    private func roomTool(_ icon: Int, _ label: String, _ destination: String) -> some View {
        Button { panel = destination } label: {
            VStack(spacing: 5) { Artwork(sheet: .navigation, tile: icon).frame(width: 30, height: 30); Text(label).font(.custom("AvenirNext-DemiBold", size: 11)) }.frame(maxWidth: .infinity).padding(.vertical, 12).background(ArtworkSurface())
        }.buttonStyle(KokoPressStyle())
    }
    private func seatView(_ position: Int, room: ListeningRoom) -> some View {
        Button {
            selectedSeat = position
            panel = room.seatAssignments[position] == nil ? (isHost ? "Invite a sample guest" : "Take this seat?") : "At this seat"
        } label: {
            VStack(spacing: 6) {
                if let memberID = room.seatAssignments[position], let member = community.member(memberID) {
                    Artwork(sheet: .collection, tile: member.portraitTile).frame(height: 58)
                    Text(member.publicName).lineLimit(1)
                    Text(room.mutedSeatNumbers.contains(position) ? "Muted" : (position == 0 ? "Host" : "On the mic")).font(.custom("AvenirNext-Regular", size: 9))
                } else { Artwork(sheet: .navigation, tile: 13).frame(height: 48).opacity(0.4); Text("Seat \(position + 1)"); Text("Join locally").font(.custom("AvenirNext-Regular", size: 9)) }
            }.font(.custom("AvenirNext-DemiBold", size: 11)).frame(maxWidth: .infinity, minHeight: 104).padding(8).background(ArtworkSurface(tile: room.seatAssignments[position] == community.myID ? 3 : 2))
        }.buttonStyle(KokoPressStyle())
    }
    private func sendRoomMessage(_ message: String) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var room else { return }
        room.roomConversation.append(.init(authorMemberID: community.myID, messageText: String(trimmed.prefix(500))))
        community.saveRoom(room)
    }
    @ViewBuilder private func roomPanel(_ title: String, room: ListeningRoom) -> some View {
        KokoModal(title: title, dismiss: { panel = nil }) {
            switch title {
            case "Send a little something":
                Text("\(community.coinBalance) coins available").font(.custom("AvenirNext-Medium", size: 13))
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
                    ForEach(KokoCommunity.keepsakes.filter { !$0.wearable }) { gift in
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
                KokoAction(title: "Open wallet", emphasis: false) { panel = nil; navigation.open(.wallet) }
            case "Invite a sample guest":
                Text("Choose a sample participant for this seat. This is local room setup; no invitation is sent.")
                let candidates = community.members.filter { !room.seatAssignments.values.contains($0.id) }
                ForEach(candidates) { member in
                    KokoAction(title: "Seat " + member.publicName, emphasis: false) {
                        guard let seat = selectedSeat, room.seatAssignments[seat] == nil else { return }
                        var updated = room; updated.seatAssignments[seat] = member.id
                        community.saveRoom(updated); panel = nil
                    }
                }
                if candidates.isEmpty { Text("Every available sample guest already has a seat.") }
            case "Take this seat?":
                Text("Try being a speaker in this local room. Your microphone is not recorded or transmitted.")
                KokoAction(title: "Take seat \((selectedSeat ?? 0) + 1)", icon: 13) {
                    guard let seat = selectedSeat, room.seatAssignments[seat] == nil else { return }
                    var updated = room
                    updated.seatAssignments = updated.seatAssignments.filter { $0.value != community.myID }
                    updated.seatAssignments[seat] = community.myID
                    community.saveRoom(updated); panel = nil
                }
            case "At this seat":
                if let seat = selectedSeat, let memberID = room.seatAssignments[seat] {
                    if let member = community.member(memberID) { KokoMemberRow(member: member) }
                    if memberID == community.myID || isHost || room.moderatorMemberIDs.contains(community.myID) {
                        KokoAction(title: room.mutedSeatNumbers.contains(seat) ? "Unmute seat locally" : "Mute seat locally", icon: 13) {
                            var updated = room
                            if updated.mutedSeatNumbers.contains(seat) { updated.mutedSeatNumbers.remove(seat) } else { updated.mutedSeatNumbers.insert(seat) }
                            community.saveRoom(updated); panel = nil
                        }
                        if seat != 0 {
                            KokoAction(title: memberID == community.myID ? "Leave my seat" : "Remove from seat", emphasis: false) { var updated = room; updated.seatAssignments.removeValue(forKey: seat); updated.mutedSeatNumbers.remove(seat); community.saveRoom(updated); panel = nil }
                        }
                    }
                    if isHost, memberID != community.myID {
                        KokoAction(title: room.moderatorMemberIDs.contains(memberID) ? "Remove moderator" : "Make room moderator", emphasis: false) {
                            var updated = room
                            if updated.moderatorMemberIDs.contains(memberID) { updated.moderatorMemberIDs.remove(memberID) } else { updated.moderatorMemberIDs.insert(memberID) }
                            community.saveRoom(updated); panel = nil
                        }
                    }
                }
            case "Room audience":
                ForEach(Array(Set(room.seatAssignments.values)).sorted(), id: \.self) { memberID in if let member = community.member(memberID) { KokoMemberRow(member: member) } }
                LocalPreviewNote(text: "SAMPLE OCCUPANTS · NO REAL-TIME AUDIENCE CONNECTED")
            case "Voice connection":
                Artwork(sheet: .navigation, tile: 13).frame(height: 90)
                Text("Join a seat to try microphone states. A real-time audio service will be connected later.")
                KokoAction(title: isHost ? "Invite a sample guest" : "Choose an open seat") { selectedSeat = (0..<room.seatLimit).first(where: { room.seatAssignments[$0] == nil }); panel = selectedSeat == nil ? nil : (isHost ? "Invite a sample guest" : "Take this seat?"); if selectedSeat == nil { community.notice = "All seats are occupied." } }
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
                KokoAction(title: "Save room note") { var updated = room; updated.hostNote = String(roomNote.prefix(200)); community.saveRoom(updated); panel = nil }
            case "Room ranking":
                Text("Local contributions").font(.custom("AvenirNext-Bold", size: 18))
                let spent = (community.journal?.walletHistory ?? []).filter { $0.detailLine.contains(room.roomTitle) && $0.tokenChange < 0 }.reduce(0) { $0 - $1.tokenChange }
                Text("Your gifts in this room: \(spent) demo coins")
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
