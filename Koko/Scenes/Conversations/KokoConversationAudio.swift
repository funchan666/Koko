import SwiftUI
import AVFoundation

// Captures only a short-lived input level. Samples are never stored, played back or transmitted.
private final class KokoInputLevelSampler: @unchecked Sendable {
    private let lock = NSLock()
    private var lastDelivery = Date.distantPast
    func read(_ buffer: AVAudioPCMBuffer) -> Float? {
        lock.lock(); defer { lock.unlock() }
        let now = Date()
        guard now.timeIntervalSince(lastDelivery) >= 0.16, buffer.frameLength > 0,
              let samples = buffer.floatChannelData?[0] else { return nil }
        lastDelivery = now
        let count = Int(buffer.frameLength)
        var energy: Float = 0
        for index in 0..<count { energy += samples[index] * samples[index] }
        let decibels = 20 * log10(max(sqrt(energy / Float(count)), 0.00001))
        return min(1, max(0, (decibels + 60) / 60))
    }
}

// Session and engine operations are serialized and the engine is recreated after route changes.
final class KokoConversationAudioPipeline: @unchecked Sendable {
    private let queue = DispatchQueue(label: "koko.conversation-audio")
    private var engine: AVAudioEngine?
    private var ownsSession = false
    func start(speaker: Bool, level: @escaping @Sendable (Float) -> Void, completion: @escaping @Sendable (Bool) -> Void) {
        queue.async { [self] in
            stopOnQueue()
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetoothHFP])
                try session.setActive(true); ownsSession = true
                try session.overrideOutputAudioPort(speaker ? .speaker : .none)
                let next = AVAudioEngine()
                let input = next.inputNode
                let format = input.outputFormat(forBus: 0)
                guard format.sampleRate > 0, format.channelCount > 0 else { stopOnQueue(); completion(false); return }
                let sampler = KokoInputLevelSampler()
                input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                    if let value = sampler.read(buffer) { level(value) }
                }
                engine = next
                next.prepare(); try next.start()
                completion(true)
            } catch { stopOnQueue(); completion(false) }
        }
    }
    func routeToSpeaker(_ speaker: Bool, completion: @escaping @Sendable (Bool) -> Void) {
        queue.async { [self] in
            guard ownsSession else { completion(false); return }
            do { try AVAudioSession.sharedInstance().overrideOutputAudioPort(speaker ? .speaker : .none); completion(true) }
            catch { completion(false) }
        }
    }
    func stop() { queue.async { [self] in stopOnQueue() } }
    private func stopOnQueue() {
        if let engine { engine.stop(); engine.inputNode.removeTap(onBus: 0) }
        engine = nil
        if ownsSession { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation); ownsSession = false }
    }
}

@MainActor
final class KokoConversationAudio: ObservableObject {
    @Published private(set) var listening = false
    @Published private(set) var requesting = false
    @Published private(set) var permissionDenied = false
    @Published private(set) var speakerEnabled = false
    @Published private(set) var inputLevel: Float = 0
    @Published private(set) var explanation = "Microphone is off. Start a device check when you're ready."
    @Published private(set) var routeName = "System audio route"
    private let pipeline = KokoConversationAudioPipeline()
    private var revision = UUID()

    func enable() async -> Bool {
        guard !requesting else { return false }
        if listening { return true }
        let attempt = UUID(); revision = attempt; requesting = true
        let granted: Bool
        if #available(iOS 17.0, *) { granted = await AVAudioApplication.requestRecordPermission() }
        else {
            granted = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning: $0) }
            }
        }
        guard revision == attempt else { return false }
        permissionDenied = !granted
        guard granted else {
            requesting = false; explanation = "Microphone access is off. Allow it in iOS Settings to use voice or video calling."
            return false
        }
        let ready = await withCheckedContinuation { continuation in
            pipeline.start(speaker: speakerEnabled, level: { [weak self] value in
                Task { @MainActor in
                    guard let self, self.revision == attempt, self.listening else { return }
                    self.inputLevel = value
                }
            }, completion: { continuation.resume(returning: $0) })
        }
        guard revision == attempt else { return false }
        requesting = false; listening = ready
        explanation = ready ? "Microphone is active for this local level check. No audio is recorded or sent." : "The microphone couldn't start. Check your audio device and try again."
        refreshRoute()
        return ready
    }
    func mute(reason: String = "Microphone is off.") {
        revision = UUID(); requesting = false; listening = false; inputLevel = 0
        pipeline.stop(); explanation = reason
    }
    func switchSpeaker() {
        guard listening, !requesting else { return }
        let enabled = !speakerEnabled; let attempt = revision
        pipeline.routeToSpeaker(enabled) { [weak self] success in
            Task { @MainActor in
                guard let self, self.revision == attempt else { return }
                if success { self.speakerEnabled = enabled; self.refreshRoute() }
                else { self.explanation = "This audio route couldn't be changed. Check the connected headset." }
            }
        }
    }
    func refreshRoute() {
        routeName = AVAudioSession.sharedInstance().currentRoute.outputs.map(\.portName).joined(separator: ", ")
        if routeName.isEmpty { routeName = "System audio route" }
    }
}

struct KokoMicrophoneControls: View {
    @ObservedObject var audio: KokoConversationAudio
    var activate: () -> Void
    var mute: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Artwork(sheet: .navigation, tile: 13).frame(width: 32, height: 32)
                Text(audio.listening ? "Your microphone" : "Microphone off").font(.custom("AvenirNext-DemiBold", size: 16))
                Spacer()
                Text(audio.listening ? "\(Int(audio.inputLevel * 100))%" : "—").monospacedDigit().font(.custom("AvenirNext-Bold", size: 20))
            }
            Text(audio.explanation).font(.custom("AvenirNext-Regular", size: 12)).foregroundStyle(KokoInk.secondary)
            HStack {
                KokoAction(title: audio.requesting ? "Checking permission…" : (audio.listening ? "Mute microphone" : "Enable microphone"), icon: 13) {
                    if audio.listening { mute() } else { activate() }
                }.disabled(audio.requesting)
                KokoAction(title: audio.speakerEnabled ? "Use system audio" : "Use speaker", emphasis: false) { audio.switchSpeaker() }.disabled(!audio.listening)
            }
            Text("Audio route · " + audio.routeName).font(.custom("AvenirNext-Regular", size: 11)).foregroundStyle(KokoInk.secondary)
            if audio.permissionDenied { KokoDeviceSettingsAction() }
        }.padding(18).background(ArtworkSurface())
    }
}

struct KokoDeviceSettingsAction: View {
    var body: some View {
        KokoAction(title: "Open iOS Settings", icon: 11, emphasis: false) {
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        }
    }
}
