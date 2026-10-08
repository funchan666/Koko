import Foundation

/// Filenames belong to the supplied collection; sample curators are not identities of people depicted.
struct CommunityMediaAsset: Identifiable, Decodable, Sendable {
    let id: String
    let momentKey: String
    let sourceFilename: String
    let sourceFolder: String
    let sourceSHA256: String
    let previewFilename: String
    let displayFilename: String?
    let mediaKind: String
    let captionLine: String
    let topicLabel: String
    let curatorMemberID: String
    let pixelWidth: Int
    let pixelHeight: Int
    let durationSeconds: Double?

    var isVideo: Bool { mediaKind == "video" }
    var sourceURL: URL? { Bundle.main.url(forResource: sourceFilename, withExtension: nil, subdirectory: sourceFolder) }
    var previewURL: URL? { Bundle.main.url(forResource: previewFilename, withExtension: nil, subdirectory: "CommunityMedia") }
    var imageURL: URL? {
        if let displayFilename { return Bundle.main.url(forResource: displayFilename, withExtension: nil, subdirectory: "CommunityMedia") }
        return isVideo ? previewURL : sourceURL
    }
    var durationLabel: String {
        let seconds = Int((durationSeconds ?? 0).rounded())
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
    var moment: SharedMoment {
        SharedMoment(id: momentKey, creatorMemberID: curatorMemberID, captionLine: captionLine,
                     topicLabel: topicLabel, coverTile: 4, bundledMovieName: nil, libraryAssetKey: id)
    }
}

enum KokoMediaLibrary {
    static let assets: [CommunityMediaAsset] = {
        guard let url = Bundle.main.url(forResource: "community-media", withExtension: "json", subdirectory: "CommunityMedia"),
              let data = try? Data(contentsOf: url),
              let collection = try? JSONDecoder().decode([CommunityMediaAsset].self, from: data) else { return [] }
        return collection
    }()
    static let photos = assets.filter { !$0.isVideo }
    static func asset(_ key: String?) -> CommunityMediaAsset? {
        guard let key else { return nil }
        return assets.first { $0.id == key }
    }
}

extension SharedMoment {
    var mediaAsset: CommunityMediaAsset? { KokoMediaLibrary.asset(libraryAssetKey) }
}
