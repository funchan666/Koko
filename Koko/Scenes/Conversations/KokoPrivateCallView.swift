import SwiftUI
import AVFoundation

// Call preparation is real device capture; a remote call requires an RTC/signaling service.
enum KokoConversationChannel: String, Hashable {
    case voice, video
    var title: String { self == .voice ? "Voice call" : "Video call" }
}

struct KokoPrivateCallView: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var audio = KokoConversationAudio()
    @StateObject private var camera = KokoLocalCamera()
    let memberID: String
    let channel: KokoConversationChannel
    @State private var prepared = false
    @State private var gateVisible = true
    @State private var visible = false
    private var permitted: Bool { community.friends.contains(memberID) && community.member(memberID) != nil }
    var body: some View {
        ZStack {
            KokoPage(title: channel.title, subtitle: "YOUR CONVERSATION, AT YOUR PACE", back: end) {
                if let member = community.member(memberID) {
                    HStack(alignment: .center, spacing: 20) {
                        KokoMemberPortrait(member: member).frame(width: 98, height: 122)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(member.publicName).font(.custom("AvenirNext-Bold", size: 26))
                            Text(permitted ? "Mutual connection" : "Follow each other first").font(.custom("AvenirNext-Medium", size: 12)).foregroundStyle(KokoInk.secondary)
                            Text("Voice and video are free.").font(.custom("AvenirNext-DemiBold", size: 12)).foregroundStyle(KokoInk.accent)
                        }
                    }
                }
                if permitted {
                    if channel == .video {
                        if camera.active {
                            KokoCameraSurface(session: camera.pipeline.captureSession).frame(height: 290).clipped()
                            Text("Only you can see this camera preview.").font(.custom("AvenirNext-Medium", size: 12))
                        } else {
                            Artwork(sheet: .navigation, tile: 0)
                                .frame(width: 30, height: 30)
                                .padding(24)
                                .background(KokoControlSurface())
                        }
                    } else {
                        Artwork(sheet: .navigation, tile: 13)
                            .frame(width: 30, height: 30)
                            .padding(24)
                            .background(KokoControlSurface())
                    }
                    KokoCard(tint: 3) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(prepared ? "Your setup is ready." : "A moment before hello.").font(.custom("AvenirNext-Bold", size: 22))
                            Text("Check your microphone\(channel == .video ? " and camera" : "") here. A calling service isn't connected yet, so nobody is being called.").font(.custom("AvenirNext-Regular", size: 14))
                        }
                    }
                    if !prepared {
                        KokoAction(title: audio.requesting ? "Checking microphone…" : "Prepare \(channel.rawValue) call", icon: channel == .video ? 0 : 13, action: prepare)
                            .disabled(audio.requesting || camera.requesting)
                    }
                    KokoMicrophoneControls(audio: audio, activate: prepareMicrophone, mute: { audio.mute() })
                    if channel == .video {
                        Text(camera.explanation).font(.custom("AvenirNext-Regular", size: 12)).foregroundStyle(KokoInk.secondary)
                        HStack {
                            KokoAction(title: camera.requesting ? "Opening camera…" : (camera.active ? "Camera off" : "Camera on"), icon: 0) {
                                guard permitted else { return }
                                if camera.active { camera.stop() } else { camera.start() }
                            }.disabled(camera.requesting)
                            KokoAction(title: "Flip camera", emphasis: false) { camera.flip() }.disabled(!camera.active || camera.requesting)
                        }
                        if camera.permissionDenied { KokoDeviceSettingsAction() }
                    }
                    KokoAction(title: "End and return", emphasis: false, action: end)
                } else {
                    Artwork(sheet: .navigation, tile: 3)
                        .frame(width: 30, height: 30)
                        .padding(24)
                        .background(KokoControlSurface())
                    Text("Calls are available between mutual followers. No permissions are requested until you're eligible and choose to check your devices.").foregroundStyle(KokoInk.secondary)
                    KokoAction(title: "View profile", emphasis: false) { navigation.open(.profile(memberID)) }
                }
            }.accessibilityHidden(!permitted && gateVisible)
            if !permitted && gateVisible {
                KokoModal(title: "A hello goes both ways.", dismiss: { gateVisible = false }) {
                    Artwork(sheet: .navigation, tile: 3)
                        .frame(width: 30, height: 30)
                        .padding(20)
                        .background(KokoControlSurface())
                    Text("Voice and video calls are for mutual followers. Open this profile to manage your connection.")
                    KokoAction(title: "Open profile") { gateVisible = false; navigation.open(.profile(memberID)) }
                    KokoAction(title: "Not now", emphasis: false, action: end)
                }
            }
        }.onAppear { visible = true }.onDisappear { visible = false; suspend() }
            .onChange(of: permitted) { allowed in if !allowed { suspend(); gateVisible = true } }
            .onChange(of: scenePhase) { phase in
                if phase == .background || (phase == .inactive && !audio.requesting && !camera.requesting) { suspend() }
            }
            .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { note in
                if (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) == AVAudioSession.InterruptionType.began.rawValue { suspend() }
            }
            .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.mediaServicesWereResetNotification)) { _ in suspend() }
            .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { note in
                audio.refreshRoute()
                if let reason = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                   reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue || reason == AVAudioSession.RouteChangeReason.newDeviceAvailable.rawValue {
                    audio.mute(reason: "Your audio device changed. Enable the microphone again when ready.")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .AVCaptureSessionWasInterrupted, object: camera.pipeline.captureSession)) { _ in camera.stop() }
            .onReceive(NotificationCenter.default.publisher(for: .AVCaptureSessionRuntimeError, object: camera.pipeline.captureSession)) { _ in camera.stop() }
    }
    private func prepareMicrophone() {
        guard permitted else { return }
        Task { guard await audio.enable() else { return }; guard visible, permitted else { audio.mute(); return }; prepared = true }
    }
    private func prepare() {
        guard permitted else { return }
        Task {
            guard await audio.enable() else { return }
            guard visible, permitted else { audio.mute(); return }
            prepared = true
            if channel == .video { camera.start() }
        }
    }
    private func suspend() { audio.mute(reason: "Device check paused. Enable your devices again when ready."); camera.stop(); prepared = false }
    private func end() { suspend(); navigation.back() }
}
