import SwiftUI
import AVFoundation

// All capture session and output operations share one serial queue.
final class KokoPortraitCapture: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "koko.profile-photo-capture")
    private let output = AVCapturePhotoOutput()
    private var delivery: (@Sendable (Data?) -> Void)?
    func start(front: Bool, ready: @escaping @Sendable (Bool) -> Void) {
        queue.async { [self] in
            session.beginConfiguration(); session.sessionPreset = .photo
            for input in session.inputs { session.removeInput(input) }
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: front ? .front : .back),
                  let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
                session.commitConfiguration()
                if session.isRunning { session.stopRunning() }
                ready(false); return
            }
            session.addInput(input)
            if session.outputs.isEmpty, session.canAddOutput(output) { session.addOutput(output) }
            session.commitConfiguration()
            guard session.outputs.contains(output) else {
                if session.isRunning { session.stopRunning() }
                ready(false); return
            }
            if !session.isRunning { session.startRunning() }
            ready(session.isRunning)
        }
    }
    func capture(deliver: @escaping @Sendable (Data?) -> Void) {
        queue.async { [self] in
            guard session.isRunning, delivery == nil else { deliver(nil); return }
            delivery = deliver
            if let connection = output.connection(with: .video) {
                if #available(iOS 17.0, *) {
                    if connection.isVideoRotationAngleSupported(90) {
                        connection.videoRotationAngle = 90
                    }
                } else if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
            output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
    }
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let data = error == nil ? photo.fileDataRepresentation() : nil
        queue.async { [self] in let callback = delivery; delivery = nil; callback?(data) }
    }
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        guard error != nil else { return }
        queue.async { [self] in let callback = delivery; delivery = nil; callback?(nil) }
    }
    func stop() { queue.async { [self] in if session.isRunning { session.stopRunning() } } }
}

@MainActor
final class KokoPortraitCameraModel: ObservableObject {
    let capture = KokoPortraitCapture()
    @Published var photoJPEG: Data?
    @Published private(set) var ready = false
    @Published private(set) var busy = false
    @Published private(set) var explanation = "Opening your camera…"
    private var front = true
    private var revision = UUID()
    func start() {
        guard !busy, photoJPEG == nil else { return }
        busy = true; ready = false
        let current = UUID(); revision = current
        Task { [weak self] in
            let granted: Bool
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: granted = true
            case .notDetermined: granted = await AVCaptureDevice.requestAccess(for: .video)
            default: granted = false
            }
            guard let self, self.revision == current else { return }
            guard granted else { self.busy = false; self.explanation = "Allow camera access in iOS Settings, or choose a photo from your library."; return }
            self.capture.start(front: self.front) { [weak self] active in
                Task { @MainActor in
                    guard let self, self.revision == current else { return }
                    self.ready = active; self.busy = false
                    self.explanation = active ? "Find your light. This photo stays on your device." : "No camera is available. You can choose a library photo instead."
                }
            }
        }
    }
    func takePhoto() {
        guard ready, !busy else { return }; busy = true
        let current = revision
        capture.capture { [weak self] data in
            // Photo processing and JPEG resizing happen away from the main actor.
            let jpeg = data.flatMap { try? KokoPortraitFiles.preparedJPEG(from: $0) }
            Task { @MainActor in
                guard let self, self.revision == current else { return }
                self.busy = false
                if let jpeg { self.photoJPEG = jpeg; self.ready = false; self.capture.stop() }
                else { self.explanation = "That photo couldn't be captured. Please try again." }
            }
        }
    }
    func flip() { guard ready, !busy else { return }; front.toggle(); start() }
    func retake() { photoJPEG = nil; start() }
    func stop() { revision = UUID(); ready = false; busy = false; capture.stop() }
}

struct KokoPortraitCameraPage: View {
    @StateObject private var camera = KokoPortraitCameraModel()
    @Environment(\.scenePhase) private var scenePhase
    let close: () -> Void
    let selected: (Data) -> Void
    var body: some View {
        KokoPage(title: "Your good side", subtitle: "A portrait for your Koko space", back: close) {
            Group {
                if let data = camera.photoJPEG, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFit()
                } else if camera.ready || camera.busy {
                    KokoCameraSurface(session: camera.capture.session)
                } else {
                    Artwork(sheet: .navigation, tile: 14)
                        .frame(width: 30, height: 30)
                        .padding(24)
                        .background(KokoControlSurface())
                }
            }.frame(height: 350).clipped()
            Text(camera.explanation).font(.custom("AvenirNext-Regular", size: 14)).foregroundStyle(KokoInk.secondary)
            if let data = camera.photoJPEG {
                KokoAction(title: "Use this photo") { selected(data) }
                KokoAction(title: "Take another", emphasis: false) { camera.retake() }
            } else {
                KokoAction(title: camera.busy ? "One moment…" : "Take photo", icon: 14) { camera.takePhoto() }.disabled(!camera.ready || camera.busy)
                KokoAction(title: "Turn camera", emphasis: false) { camera.flip() }.disabled(!camera.ready || camera.busy)
            }
            KokoAction(title: "Back to profile", emphasis: false, action: close)
        }.onAppear { camera.start() }.onDisappear { camera.stop() }
            .onChange(of: scenePhase) { phase in if phase == .active { camera.start() } else { camera.stop() } }
    }
}
