import SwiftUI
import ImageIO
import UniformTypeIdentifiers

// Preparing a user photograph, not generating UI artwork. Metadata is not copied to the JPEG.
enum KokoPortraitFiles {
    enum PortraitFailure: LocalizedError {
        case unreadable
        var errorDescription: String? { "This photo couldn't be opened. Choose another image or take a new photo." }
    }
    static func preparedJPEG(from source: Data) throws -> Data {
        guard source.count <= 60_000_000,
              let imageSource = CGImageSourceCreateWithData(source as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 900
              ] as CFDictionary) else { throw PortraitFailure.unreadable }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { throw PortraitFailure.unreadable }
        CGImageDestinationAddImage(destination, thumbnail, [kCGImageDestinationLossyCompressionQuality: 0.86] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw PortraitFailure.unreadable }
        return output as Data
    }
    private static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("KokoPortraits", isDirectory: true)
    }
    static func url(for filename: String) -> URL? {
        guard filename == (filename as NSString).lastPathComponent, filename.hasSuffix(".jpg"), UUID(uuidString: String(filename.dropLast(4))) != nil else { return nil }
        return directory.appendingPathComponent(filename)
    }
    static func save(_ jpeg: Data) throws -> String {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = UUID().uuidString + ".jpg"
        try jpeg.write(to: directory.appendingPathComponent(filename), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return filename
    }
    static func remove(_ filename: String) { if let url = url(for: filename) { try? FileManager.default.removeItem(at: url) } }
}

/// One source of truth for portraits in profiles, discovery, rooms and calls.
struct KokoMemberPortrait: View {
    let member: CommunityMember
    var body: some View {
        Group {
            if let filename = member.portraitFileName, let url = KokoPortraitFiles.url(for: filename), let photo = UIImage(contentsOfFile: url.path) {
                KokoPortraitPhoto(image: photo)
            } else if let key = member.suppliedPortraitPhotoKey, let photo = KokoSuppliedPortraitPhotos.image(for: key) {
                KokoPortraitPhoto(image: photo)
            } else {
                KokoPhotoPlaceholder()
            }
        }.accessibilityLabel(member.portraitFileName != nil || member.suppliedPortraitPhotoKey != nil ? "Profile photo of \(member.publicName)" : "No profile photo added")
    }
}

struct KokoPhotoPlaceholder: View {
    var body: some View {
        Image("KokoPhotoPlaceholder").resizable().scaledToFit().accessibilityHidden(true)
    }
}

/// Room covers use the same person's original photograph with a wider crop.
struct KokoMemberCoverPhoto: View {
    let member: CommunityMember
    var body: some View {
        Group {
            if let filename = member.portraitFileName,
               let url = KokoPortraitFiles.url(for: filename), let photo = UIImage(contentsOfFile: url.path) {
                KokoPortraitPhoto(image: photo)
            } else if let photograph = KokoMediaLibrary.asset(member.suppliedPortraitPhotoKey) {
                KokoContentImage(asset: photograph, fullResolution: true)
            } else {
                KokoPhotoPlaceholder()
            }
        }.accessibilityLabel("Room cover for " + member.publicName)
    }
}

struct KokoPortraitPhoto: View {
    let image: UIImage
    var body: some View {
        GeometryReader { bounds in
            Image(uiImage: image).resizable().scaledToFill()
                .frame(width: bounds.size.width, height: bounds.size.height).clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

@MainActor
private enum KokoSuppliedPortraitPhotos {
    private static var prepared: [String: UIImage] = [:]
    // Display crops of user-supplied photos; the original files and content collection stay intact.
    private static let portraitWindows: [String: CGRect] = [
        "photo-3e29a87b4e9a5de9": CGRect(x: 0.25, y: 0.23, width: 0.50, height: 0.375),
        "photo-f18f8ac9ab90dab5": CGRect(x: 0.42, y: 0.13, width: 0.48, height: 0.36),
        "photo-d1360451d8292f40": CGRect(x: 0.30, y: 0.29, width: 0.48, height: 0.36),
        "photo-393c437ceadbdcb4": CGRect(x: 0.27, y: 0.23, width: 0.48, height: 0.36)
    ]
    static func image(for key: String) -> UIImage? {
        if let cached = prepared[key] { return cached }
        guard let asset = KokoMediaLibrary.asset(key), !asset.isVideo,
              let url = asset.previewURL, let photo = UIImage(contentsOfFile: url.path),
              let source = photo.cgImage else { return nil }
        let window = portraitWindows[key] ?? CGRect(x: 0, y: 0, width: 1, height: 1)
        let crop = CGRect(x: window.minX * CGFloat(source.width), y: window.minY * CGFloat(source.height),
                          width: window.width * CGFloat(source.width), height: window.height * CGFloat(source.height))
        guard let pixels = source.cropping(to: crop.integral) else { return nil }
        let image = UIImage(cgImage: pixels, scale: photo.scale, orientation: .up)
        prepared[key] = image
        return image
    }
}
