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

struct KokoMemberPortrait: View {
    let member: CommunityMember
    var body: some View {
        if let filename = member.portraitFileName, let url = KokoPortraitFiles.url(for: filename), let photo = UIImage(contentsOfFile: url.path) {
            Image(uiImage: photo).resizable().scaledToFit().accessibilityLabel("Profile photo of \(member.publicName)")
        } else { Artwork(sheet: .collection, tile: member.portraitTile) }
    }
}
