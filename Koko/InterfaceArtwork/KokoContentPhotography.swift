import SwiftUI
import ImageIO

/// Immutable decoded pixels cross the worker boundary; all cache and view state stays on the main actor.
private struct PreparedContentImage: @unchecked Sendable {
    let image: UIImage?
}

@MainActor
private enum ContentImageCache {
    static let images: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 36 * 1024 * 1024
        return cache
    }()

    static func image(at url: URL, maximumPixels: Int) async -> UIImage? {
        let key = (url.path + "@\(maximumPixels)") as NSString
        if let existing = images.object(forKey: key) { return existing }
        let prepared = await Task.detached(priority: .userInitiated) {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let pixels = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: maximumPixels,
                    kCGImageSourceShouldCacheImmediately: true
                  ] as CFDictionary) else { return PreparedContentImage(image: nil) }
            return PreparedContentImage(image: UIImage(cgImage: pixels))
        }.value
        guard !Task.isCancelled, let image = prepared.image else { return nil }
        images.setObject(image, forKey: key, cost: Int(image.size.width * image.size.height) * 4)
        return image
    }
}

struct KokoContentImage: View {
    let asset: CommunityMediaAsset
    var fullResolution = false
    var fitInside = false
    @State private var decodedImage: UIImage?
    @State private var unavailable = false
    private var resourceURL: URL? { fullResolution ? asset.imageURL : asset.previewURL }
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let decodedImage {
                    Image(uiImage: decodedImage).resizable()
                        .aspectRatio(contentMode: fitInside ? .fit : .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else {
                    Artwork(sheet: .collection, tile: 4)
                    if unavailable { Text("Image unavailable").font(.custom("AvenirNext-Medium", size: 12)).padding(8).background(ArtworkSurface()) }
                }
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }
        .accessibilityLabel(asset.captionLine)
        .task(id: resourceURL) {
            decodedImage = nil; unavailable = false
            guard let url = resourceURL else { unavailable = true; return }
            let prepared = await ContentImageCache.image(at: url, maximumPixels: fullResolution ? 1800 : 640)
            guard !Task.isCancelled else { return }
            decodedImage = prepared; unavailable = prepared == nil
        }
    }
}

struct KokoCollectionPhotoPicker: View {
    @Binding var selectedPhotoKey: String?
    var body: some View {
        Text("\(KokoMediaLibrary.photos.count) photos in the collection").font(.custom("AvenirNext-Regular", size: 12)).foregroundStyle(KokoInk.secondary)
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(KokoMediaLibrary.photos) { photo in
                    Button { selectedPhotoKey = photo.id } label: {
                        VStack(spacing: 4) {
                            KokoContentImage(asset: photo).frame(height: 105)
                            Text(selectedPhotoKey == photo.id ? "Selected" : photo.captionLine)
                                .font(.custom("AvenirNext-Medium", size: 10)).lineLimit(1)
                        }.padding(6).background(ArtworkSurface(tile: selectedPhotoKey == photo.id ? 3 : 2))
                    }.buttonStyle(KokoPressStyle()).accessibilityAddTraits(selectedPhotoKey == photo.id ? .isSelected : [])
                }
            }
        }.frame(height: 350)
    }
}
