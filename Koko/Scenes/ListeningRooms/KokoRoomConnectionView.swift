import SwiftUI
import AVFoundation

struct KokoRoomConnectionView: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var audio = KokoConversationAudio()
    @StateObject private var camera = KokoLocalCamera()
    let roomID: String
    var preferredSeat: Int? = nil
    @State private var requestPlacedAt: Date?
    @State private var localStageStartedAt: Date?
    @State private var pending = false
    @State private var visible = false
    private var room: ListeningRoom? { community.room(roomID) }
    private var mySeat: Int? { room?.seatAssignments.first(where: { $0.value == community.myID })?.key }
    private var isHost: Bool { room?.hostMemberID == community.myID }
    var body: some View {
        KokoPage(title: "A seat in the conversation", subtitle: room?.roomTitle ?? "Room connection", back: leave) {
            Artwork(sheet: .navigation, tile: 13)
                .frame(width: 30, height: 30)
                .padding(24)
                .background(KokoControlSurface())
            if let room {
                KokoCard(tint: 3) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(localStageStartedAt != nil ? "Your room stage" : (requestPlacedAt != nil ? "Your request is waiting" : "Bring your voice to the table.")).font(.custom("AvenirNext-Bold", size: 23))
                        Text("Room setup · no host is contacted and no audio is sent. Voice, video and seat requests are free.").font(.custom("AvenirNext-Regular", size: 13))
                        if let started = localStageStartedAt ?? requestPlacedAt {
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                Text("\(localStageStartedAt != nil ? "Device-check time" : "Waiting") · \(duration(since: started, now: context.date))")
                                    .font(.custom("AvenirNext-DemiBold", size: 16)).monospacedDigit()
                            }
                        }
                    }
                }
                if localStageStartedAt == nil {
                    if requestPlacedAt == nil {
                        Text("Microphone access is checked when you request a seat. Browsing the room never opens it.").font(.custom("AvenirNext-Regular", size: 13)).foregroundStyle(KokoInk.secondary)
                        KokoAction(title: pending ? "Checking microphone…" : (isHost ? "Prepare my host seat" : "Request a seat"), icon: 13, action: requestSeat).disabled(pending)
                    } else {
                        if let member = community.currentMember { KokoMemberRow(member: member) }
                        Text("This request is saved only for this open panel. You can cancel, or try the room controls yourself.").font(.custom("AvenirNext-Regular", size: 13))
                        KokoAction(title: "Try the room stage", icon: 13, action: enterStage).disabled(pending)
                        KokoAction(title: "Cancel request", emphasis: false) { pause(); requestPlacedAt = nil }
                    }
                    Text(audio.explanation).font(.custom("AvenirNext-Regular", size: 12)).foregroundStyle(KokoInk.secondary)
                    if audio.permissionDenied { KokoDeviceSettingsAction() }
                } else {
                    KokoMicrophoneControls(audio: audio, activate: enableStageMicrophone, mute: muteStage)
                    if room.isVideoStage {
                        if camera.active { KokoCameraSurface(session: camera.pipeline.captureSession).frame(height: 240).clipped() }
                        Text(camera.explanation).font(.custom("AvenirNext-Regular", size: 12))
                        HStack {
                            KokoAction(title: camera.requesting ? "Opening camera…" : (camera.active ? "Camera off" : "Camera on"), icon: 0) { if camera.active { camera.stop() } else { camera.start() } }.disabled(camera.requesting)
                            KokoAction(title: "Flip camera", emphasis: false) { camera.flip() }.disabled(!camera.active || camera.requesting)
                        }
                        if camera.permissionDenied { KokoDeviceSettingsAction() }
                    }
                    KokoAction(title: isHost ? "End device check" : "Leave my seat", emphasis: false, action: leave)
                }
                Text("At the table · \(room.seatAssignments.count)/\(room.seatLimit)").font(.custom("AvenirNext-Bold", size: 20))
                ForEach(room.seatAssignments.keys.sorted(), id: \.self) { seat in
                    if let memberID = room.seatAssignments[seat], let member = community.member(memberID) {
                        HStack { KokoMemberPortrait(member: member).frame(width: 44, height: 50); Text(member.publicName); Spacer(); Text(seat == 0 ? "Host" : "Seat \(seat + 1)").font(.custom("AvenirNext-Medium", size: 12)) }
                            .padding(12).background(ArtworkSurface())
                    }
                }
            } else { KokoEmpty(title: "Room unavailable", detail: "Return to the room directory to choose another conversation.") }
        }.onAppear { visible = true }.onDisappear { visible = false; pause(); releaseGuestSeat() }
            .onChange(of: scenePhase) { phase in
                if phase == .background || (phase == .inactive && !audio.requesting && !camera.requesting) { pause() }
            }
            .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { note in
                if (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) == AVAudioSession.InterruptionType.began.rawValue { pause() }
            }
            .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.mediaServicesWereResetNotification)) { _ in pause() }
            .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { note in
                audio.refreshRoute()
                if let reason = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                   reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue || reason == AVAudioSession.RouteChangeReason.newDeviceAvailable.rawValue { muteStage() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .AVCaptureSessionWasInterrupted, object: camera.pipeline.captureSession)) { _ in camera.stop() }
            .onReceive(NotificationCenter.default.publisher(for: .AVCaptureSessionRuntimeError, object: camera.pipeline.captureSession)) { _ in camera.stop() }
    }
    private func requestSeat() {
        guard !pending, room != nil else { return }
        pending = true
        Task {
            let ready = await audio.enable(); pending = false
            guard ready else { return }
            guard visible, room != nil else { audio.mute(); return }
            if isHost { completeStageEntry() }
            else { audio.mute(reason: "Microphone permission is ready. Input stays off while you wait."); requestPlacedAt = Date() }
        }
    }
    private func enterStage() {
        guard !pending, requestPlacedAt != nil else { return }
        pending = true
        Task { let ready = await audio.enable(); pending = false; if ready { completeStageEntry() } }
    }
    private func completeStageEntry() {
        guard visible, var room else { audio.mute(); return }
        let vacantSeat = preferredSeat.flatMap { (0..<room.seatLimit).contains($0) && room.seatAssignments[$0] == nil ? $0 : nil }
        guard let seat = mySeat ?? vacantSeat ?? (0..<room.seatLimit).first(where: { room.seatAssignments[$0] == nil }) else {
            audio.mute(); community.notice = "All seats are occupied. Cancel your request or try again later."; return
        }
        room.seatAssignments[seat] = community.myID; room.mutedSeatNumbers.remove(seat)
        guard community.saveRoom(room) else { audio.mute(); return }
        localStageStartedAt = Date(); requestPlacedAt = nil
    }
    private func enableStageMicrophone() {
        guard localStageStartedAt != nil, mySeat != nil else { return }
        Task {
            guard await audio.enable() else { return }
            guard visible, var room, let seat = mySeat else { audio.mute(); return }
            room.mutedSeatNumbers.remove(seat)
            if !community.saveRoom(room) { audio.mute() }
        }
    }
    private func muteStage() {
        audio.mute()
        if var room, let seat = mySeat, !room.mutedSeatNumbers.contains(seat) { room.mutedSeatNumbers.insert(seat); _ = community.saveRoom(room) }
    }
    private func pause() { muteStage(); camera.stop(); pending = false }
    private func releaseGuestSeat() { if !isHost, mySeat != nil { community.leaveSeat(in: roomID) } }
    private func leave() { pause(); releaseGuestSeat(); requestPlacedAt = nil; localStageStartedAt = nil; navigation.back() }
    private func duration(since date: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
