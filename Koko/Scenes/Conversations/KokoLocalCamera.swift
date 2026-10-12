import SwiftUI
import AVFoundation

// Session mutations are confined to the serial queue. The preview layer only consumes the session.
final class KokoCapturePipeline: @unchecked Sendable {
    let captureSession = AVCaptureSession()
    private let captureQueue = DispatchQueue(label: "koko.private-camera-preview")
    func start(front: Bool, completion: @escaping @Sendable (Bool) -> Void) {
        captureQueue.async { [self] in
            captureSession.beginConfiguration()
            captureSession.sessionPreset = .medium
            captureSession.automaticallyConfiguresApplicationAudioSession = false
            for input in captureSession.inputs { captureSession.removeInput(input) }
            let position: AVCaptureDevice.Position = front ? .front : .back
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
                  let input = try? AVCaptureDeviceInput(device: device), captureSession.canAddInput(input) else {
                captureSession.commitConfiguration()
                if captureSession.isRunning { captureSession.stopRunning() }
                completion(false)
                return
            }
            captureSession.addInput(input)
            captureSession.commitConfiguration()
            if !captureSession.isRunning { captureSession.startRunning() }
            completion(captureSession.isRunning)
        }
    }
    func stop() { captureQueue.async { [self] in if captureSession.isRunning { captureSession.stopRunning() } } }
}

@MainActor
final class KokoLocalCamera: ObservableObject {
    let pipeline = KokoCapturePipeline()
    @Published private(set) var active = false
    @Published private(set) var requesting = false
    @Published private(set) var offersCameraSettings = false
    @Published private(set) var front = true
    @Published private(set) var explanation = "Camera is off. Preview stays on this device."
    private var requestRevision = UUID()
    @discardableResult
    func start() async -> Bool {
        guard !requesting else { return false }
        let revision = UUID(); requestRevision = revision; requesting = true
        offersCameraSettings = false
        let decision = await KokoCapturePermission.cameraDecision()
        guard requestRevision == revision else { return false }
        switch decision {
        case .allowed: break
        case .declinedNow:
            requesting = false; explanation = "Camera is off."
            return false
        case .deniedPreviously:
            requesting = false; offersCameraSettings = true
            explanation = "Camera access is unavailable. You can continue without video or review access in Settings."
            return false
        case .restricted:
            requesting = false; explanation = "Camera access is restricted on this device."
            return false
        }
        let ready = await withCheckedContinuation { continuation in
            pipeline.start(front: front) { continuation.resume(returning: $0) }
        }
        guard requestRevision == revision else { return false }
        requesting = false; active = ready
        explanation = ready ? "Only you can see this. Nothing is recorded or sent." : "A camera isn't available on this device. The call layout can still be previewed."
        return ready
    }
    func flip() {
        guard active, !requesting else { return }
        front.toggle()
        let revision = requestRevision
        Task { guard active, requestRevision == revision else { return }; await start() }
    }
    func stop() {
        requestRevision = UUID(); requesting = false; active = false; offersCameraSettings = false
        pipeline.stop(); explanation = "Camera is off. Preview stays on this device."
    }

}

struct KokoCameraSurface: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> KokoCameraLayerView {
        let view = KokoCameraLayerView(); view.previewLayer.videoGravity = .resizeAspectFill; view.previewLayer.session = session; return view
    }
    func updateUIView(_ view: KokoCameraLayerView, context: Context) { view.previewLayer.session = session }
    static func dismantleUIView(_ view: KokoCameraLayerView, coordinator: ()) { view.previewLayer.session = nil }
}

final class KokoCameraLayerView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
