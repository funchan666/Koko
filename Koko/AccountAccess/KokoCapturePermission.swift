import AVFoundation

enum KokoCapturePermission {
    enum Decision: Equatable, Sendable {
        case allowed
        case declinedNow
        case deniedPreviously
        case restricted
    }

    static func cameraDecision() async -> Decision {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .allowed
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video) ? .allowed : .declinedNow
        case .denied: return .deniedPreviously
        case .restricted: return .restricted
        @unknown default: return .restricted
        }
    }

    static func microphoneDecision() async -> Decision {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted: return .allowed
        case .denied: return .deniedPreviously
        case .undetermined:
            let allowed: Bool
            if #available(iOS 17.0, *) { allowed = await AVAudioApplication.requestRecordPermission() }
            else {
                allowed = await withCheckedContinuation { continuation in
                    AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning: $0) }
                }
            }
            return allowed ? .allowed : .declinedNow
        @unknown default: return .restricted
        }
    }
}
