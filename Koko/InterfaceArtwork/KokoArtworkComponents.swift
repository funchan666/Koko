import SwiftUI
import UIKit

enum KokoInk {
    static let primary = Color(red: 0.07, green: 0.20, blue: 0.18)
    static let secondary = Color(red: 0.31, green: 0.40, blue: 0.37)
    static let accent = Color(red: 0.16, green: 0.40, blue: 0.32)
    static let warning = Color(red: 0.65, green: 0.20, blue: 0.16)
}

enum ArtworkSheet: String {
    case navigation = "KokoNavigation", surfaces = "KokoSurfaces", scenes = "KokoScenes", collection = "KokoCollection", arrival = "KokoArrival"
    var columns: Int { self == .surfaces || self == .scenes || self == .arrival ? 2 : 4 }
    var rows: Int { self == .surfaces ? 3 : (self == .scenes || self == .arrival ? 2 : 4) }
}

@MainActor
enum OriginalArtwork {
    private static var tiles: [String: UIImage] = [:]
    // Extracts tiles from original Image 2 artwork. Does not draw or synthesize graphics.
    static func image(_ sheet: ArtworkSheet, _ tile: Int) -> UIImage {
        let key = "\(sheet.rawValue).\(tile)"
        if let image = tiles[key] { return image }
        guard let source = UIImage(named: sheet.rawValue)?.cgImage else { return UIImage() }
        let width = source.width / sheet.columns
        let height = source.height / sheet.rows
        let region = CGRect(x: CGFloat((tile % sheet.columns) * width), y: CGFloat((tile / sheet.columns) * height), width: CGFloat(width), height: CGFloat(height))
        guard let crop = source.cropping(to: region) else { return UIImage() }
        let image = UIImage(cgImage: crop, scale: 2, orientation: .up)
        tiles[key] = image
        return image
    }
}

struct Artwork: View {
    let sheet: ArtworkSheet
    let tile: Int
    var body: some View {
        Image(uiImage: OriginalArtwork.image(sheet, tile)).resizable().scaledToFit()
            .blendMode(sheet == .navigation || sheet == .collection || sheet == .arrival ? .multiply : .normal)
            .accessibilityHidden(true)
    }
}

struct ArtworkSurface: View {
    var tile = 2
    var body: some View {
        Image(uiImage: OriginalArtwork.image(.surfaces, tile))
            .resizable(capInsets: EdgeInsets(top: 40, leading: 40, bottom: 40, trailing: 40), resizingMode: .stretch)
            .accessibilityHidden(true)
    }
}

struct ArtworkBackdrop: View {
    var dark = false
    var body: some View {
        Image(uiImage: OriginalArtwork.image(.surfaces, dark ? 1 : 0)).resizable().ignoresSafeArea().accessibilityHidden(true)
    }
}

struct KokoAction: View {
    var title: String
    var icon: Int? = nil
    var emphasis = true
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Artwork(sheet: .navigation, tile: icon).frame(width: 25, height: 25) }
                Text(title).font(.custom("AvenirNext-DemiBold", size: 15, relativeTo: .body)).multilineTextAlignment(.center)
            }
            .foregroundStyle(KokoInk.primary)
            .padding(.horizontal, 20).padding(.vertical, 15)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(ArtworkSurface(tile: emphasis ? 3 : 5))
        }
        .buttonStyle(KokoPressStyle())
    }
}

struct KokoPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
    }
}

struct KokoIconAction: View {
    let icon: Int
    let label: String
    var action: () -> Void
    var body: some View {
        Button(action: action) { Artwork(sheet: .navigation, tile: icon).frame(width: 28, height: 28).frame(width: 48, height: 48).background(ArtworkSurface()) }
            .buttonStyle(KokoPressStyle()).accessibilityLabel(label)
    }
}

struct KokoCard<Content: View>: View {
    var tint = 2
    @ViewBuilder var content: Content
    var body: some View { content.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(ArtworkSurface(tile: tint)) }
}

struct KokoField: View {
    let label: String
    @Binding var value: String
    var secure = false
    var keyboard: UIKeyboardType = .default
    var multiline = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.custom("AvenirNext-DemiBold", size: 12)).foregroundStyle(KokoInk.secondary)
            Group {
                if secure { SecureField(label, text: $value) }
                else if multiline { TextField(label, text: $value, axis: .vertical).lineLimit(3...6) }
                else { TextField(label, text: $value) }
            }
            .textFieldStyle(.plain).keyboardType(keyboard).textInputAutocapitalization(.never).autocorrectionDisabled()
            .padding(16).frame(minHeight: 52).background(ArtworkSurface(tile: 5))
        }
    }
}

struct KokoChoiceRail: View {
    let choices: [String]
    @Binding var selection: String
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(choices, id: \.self) { choice in
                    Button { selection = choice } label: {
                        Text(choice).font(.custom("AvenirNext-DemiBold", size: 13)).foregroundStyle(KokoInk.primary)
                            .padding(.horizontal, 16).frame(minHeight: 46)
                            .background(ArtworkSurface(tile: selection == choice ? 3 : 2))
                    }.buttonStyle(KokoPressStyle()).accessibilityAddTraits(selection == choice ? .isSelected : [])
                }
            }
        }
    }
}

struct LocalPreviewNote: View {
    var text = "LOCAL PREVIEW · SAVED ON THIS DEVICE"
    var body: some View { Text(text).font(.custom("AvenirNext-DemiBold", size: 10)).tracking(1.3).foregroundStyle(KokoInk.secondary).fixedSize(horizontal: false, vertical: true) }
}

struct KokoPage<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var back: (() -> Void)? = nil
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                if let back { KokoIconAction(icon: 5, label: "Back", action: back) }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.custom("AvenirNext-Bold", size: 28, relativeTo: .title)).foregroundStyle(KokoInk.primary)
                    if let subtitle { Text(subtitle).font(.custom("AvenirNext-Regular", size: 13)).foregroundStyle(KokoInk.secondary) }
                }
                Spacer(minLength: 0)
            }.padding(.horizontal, 22).padding(.top, 10).padding(.bottom, 12)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) { content }
                    .frame(maxWidth: 680).frame(maxWidth: .infinity).padding(.horizontal, 22).padding(.top, 6).padding(.bottom, 28)
            }.scrollDismissesKeyboard(.interactively)
        }.background(ArtworkBackdrop())
    }
}

struct KokoEmpty: View {
    let title: String
    let detail: String
    var art = 2
    var body: some View {
        VStack(spacing: 12) {
            Artwork(sheet: .scenes, tile: art).frame(height: 170)
            Text(title).font(.custom("AvenirNext-DemiBold", size: 21))
            Text(detail).font(.custom("AvenirNext-Regular", size: 14)).foregroundStyle(KokoInk.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 18)
    }
}

struct KokoMenuRow: View {
    let title: String
    var detail: String = ""
    var icon = 3
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Artwork(sheet: .navigation, tile: icon).frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.custom("AvenirNext-DemiBold", size: 16))
                    if !detail.isEmpty { Text(detail).font(.custom("AvenirNext-Regular", size: 12)).foregroundStyle(KokoInk.secondary) }
                }
                Spacer()
                Artwork(sheet: .navigation, tile: 5).rotationEffect(.degrees(180)).frame(width: 18, height: 18)
            }.foregroundStyle(KokoInk.primary).padding(18).background(ArtworkSurface())
        }.buttonStyle(KokoPressStyle())
    }
}

struct KokoToggleRow: View {
    let title: String
    @Binding var enabled: Bool
    var body: some View {
        Button { enabled.toggle() } label: {
            HStack {
                Text(title).font(.custom("AvenirNext-Medium", size: 15))
                Spacer()
                Text(enabled ? "ON" : "OFF").font(.custom("AvenirNext-Bold", size: 12)).padding(12).background(ArtworkSurface(tile: enabled ? 3 : 5))
            }.padding(12).background(ArtworkSurface())
        }.buttonStyle(KokoPressStyle()).accessibilityValue(enabled ? "On" : "Off")
    }
}

struct KokoModal<Content: View>: View {
    let title: String
    var dismiss: () -> Void
    @ViewBuilder var content: Content
    var body: some View {
        ZStack {
            ArtworkBackdrop(dark: true).opacity(0.97).onTapGesture(perform: dismiss)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack { Text(title).font(.custom("AvenirNext-Bold", size: 22)); Spacer(); KokoIconAction(icon: 6, label: "Close", action: dismiss) }
                    content
                }.padding(24).background(ArtworkSurface()).padding(22).frame(maxWidth: 580)
                    .frame(maxWidth: .infinity)
            }.defaultScrollAnchorCompat()
        }.accessibilityElement(children: .contain)
    }
}

private extension View {
    func defaultScrollAnchorCompat() -> some View { self.frame(maxHeight: .infinity, alignment: .center) }
}
