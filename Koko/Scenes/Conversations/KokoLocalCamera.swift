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
    @Published private(set) var front = true
    @Published private(set) var explanation = "Camera is off. Preview stays on this device."
    private var requestRevision = UUID()
    func start() {
        guard !requesting else { return }
        let revision = UUID(); requestRevision = revision; requesting = true
        Task { [weak self] in
            let granted: Bool
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: granted = true
            case .notDetermined: granted = await AVCaptureDevice.requestAccess(for: .video)
            default: granted = false
            }
            guard let self, self.requestRevision == revision else { return }
            guard granted else { self.requesting = false; self.explanation = "Camera permission is off. You can enable it in iOS Settings."; return }
            self.pipeline.start(front: self.front) { [weak self] ready in
                Task { @MainActor in
                    guard let self, self.requestRevision == revision else { return }
                    self.requesting = false; self.active = ready
                    self.explanation = ready ? "Only you can see this. Nothing is recorded or sent." : "A camera isn't available on this device. The call layout can still be previewed."
                }
            }
        }
    }
    func flip() { guard !requesting else { return }; front.toggle(); if active { start() } }
    func stop() { requestRevision = UUID(); requesting = false; active = false; pipeline.stop(); explanation = "Camera is off. Preview stays on this device." }
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
