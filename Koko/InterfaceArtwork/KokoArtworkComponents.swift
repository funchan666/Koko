import SwiftUI
import UIKit

enum KokoInk {
    static let primary = KokoWelcomePalette.paper
    // Keep the palette vocabulary explicit for artwork overlays and controls.
    static let paper = KokoWelcomePalette.paper
    static let secondary = KokoWelcomePalette.quiet
    static let accent = KokoWelcomePalette.mint
    static let coral = Color(red: 0.98, green: 0.48, blue: 0.39)
    static let peach = Color(red: 1.0, green: 0.76, blue: 0.62)
    static let warning = Color(red: 0.96, green: 0.70, blue: 0.59)
    static let canvas = KokoWelcomePalette.backdrop
    static let panel = Color(red: 26 / 255, green: 58 / 255, blue: 52 / 255)
    static let panelRaised = Color(red: 37 / 255, green: 76 / 255, blue: 67 / 255)
    static let line = Color.white.opacity(0.17)
    static let onMint = KokoWelcomePalette.backdrop
}

enum ArtworkSheet: String {
    case navigation = "KokoCommunityNavigation", surfaces = "KokoSurfaces", scenes = "KokoCommunityScenes", collection = "KokoCommunityCollection", arrival = "KokoArrival", social = "KokoSocialAtlas", tabs = "KokoTabIcons", liveControls = "KokoLiveRoomControls"
    var columns: Int { self == .surfaces || self == .scenes || self == .arrival || self == .social || self == .tabs ? 2 : (self == .liveControls ? 3 : 4) }
    var rows: Int { self == .surfaces ? 3 : (self == .scenes || self == .arrival || self == .social || self == .tabs ? 2 : (self == .liveControls ? 2 : 4)) }
}

@MainActor
enum OriginalArtwork {
    private static var tiles: [String: UIImage] = [:]
    // Only crops original raster assets. Artwork is never synthesized in code.
    static func image(_ sheet: ArtworkSheet, _ tile: Int) -> UIImage {
        let key = "\(sheet.rawValue).\(tile)"
        if let image = tiles[key] { return image }
        let name = sheet == .arrival ? "KokoCommunityScenes" : sheet.rawValue
        guard let source = UIImage(named: name)?.cgImage else { return UIImage() }
        let selectedTile = sheet == .arrival ? [1, 0, 2, 3][min(max(tile, 0), 3)] : min(max(tile, 0), sheet.columns * sheet.rows - 1)
        let width = CGFloat(source.width) / CGFloat(sheet.columns)
        let height = CGFloat(source.height) / CGFloat(sheet.rows)
        let region = CGRect(x: CGFloat(selectedTile % sheet.columns) * width, y: CGFloat(selectedTile / sheet.columns) * height, width: width, height: height)
        guard let crop = source.cropping(to: region) else { return UIImage() }
        let image = UIImage(cgImage: crop, scale: 3, orientation: .up)
        tiles[key] = image
        return image
    }
    static func panel(highlighted: Bool) -> UIImage {
        let key = "community-panel-\(highlighted)"
        if let image = tiles[key] { return image }
        guard let source = UIImage(named: "KokoCommunitySurfaces")?.cgImage else { return UIImage() }
        let w = CGFloat(source.width), h = CGFloat(source.height)
        let area = CGRect(x: (highlighted ? 0.51 : 0.04) * w, y: 0.07 * h, width: 0.45 * w, height: 0.86 * h)
        guard let crop = source.cropping(to: area) else { return UIImage() }
        let image = UIImage(cgImage: crop, scale: 8, orientation: .up)
        tiles[key] = image
        return image
    }
    static func control(highlighted: Bool) -> UIImage {
        let key = "community-control-\(highlighted)"
        if let image = tiles[key] { return image }
        guard let source = UIImage(named: "KokoProfileSelection")?.cgImage else { return UIImage() }
        let scale = CGFloat(source.width) / 1254
        let area = CGRect(x: 62 * scale, y: (highlighted ? 668 : 272) * scale, width: 1130 * scale, height: 338 * scale)
        guard let crop = source.cropping(to: area) else { return UIImage() }
        let image = UIImage(cgImage: crop, scale: 6 * scale, orientation: .up)
        tiles[key] = image
        return image
    }
}

struct Artwork: View {
    let sheet: ArtworkSheet
    let tile: Int
    var ink: Color = KokoInk.accent
    var body: some View {
        Group {
            if sheet == .navigation {
                // The original monochrome bitmap supplies the glyph; this only masks its black matte.
                ink.mask {
                    Image(uiImage: OriginalArtwork.image(sheet, tile)).resizable().scaledToFit()
                        .luminanceToAlpha()
                }
            } else {
                Image(uiImage: OriginalArtwork.image(sheet, tile)).resizable().scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }.accessibilityHidden(true)
    }
}

struct ArtworkSurface: View {
    @Environment(\.kokoDialogContent) private var inDialog
    var tile = 2
    var body: some View {
        if inDialog {
            KokoDialogControlSurface()
        } else {
            Image(uiImage: OriginalArtwork.panel(highlighted: tile == 3))
                .resizable(capInsets: EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18))
                .overlay {
                    LinearGradient(
                        colors: [KokoInk.accent.opacity(tile == 3 ? 0.12 : 0.035), Color.clear, KokoInk.coral.opacity(tile == 3 ? 0.04 : 0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .shadow(color: Color.black.opacity(0.16), radius: 14, y: 8)
                .accessibilityHidden(true)
        }
    }
}


struct KokoControlSurface: View {
    @Environment(\.kokoDialogContent) private var inDialog
    var highlighted = false
    var body: some View {
        if inDialog {
            KokoDialogControlSurface(prominent: highlighted)
        } else {
            Image(uiImage: OriginalArtwork.control(highlighted: highlighted))
                .resizable(capInsets: EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18))
                .overlay {
                    LinearGradient(
                        colors: highlighted ? [KokoInk.paper.opacity(0.28), KokoInk.accent.opacity(0.72)] : [KokoInk.accent.opacity(0.08), Color.clear, KokoInk.coral.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .shadow(color: Color.black.opacity(highlighted ? 0.08 : 0.18), radius: 10, y: 5)
                .accessibilityHidden(true)
        }
    }
}


struct KokoGradientBackdrop: View {
    var body: some View {
        Image("KokoSocialCanvasBackground")
            .resizable()
            .scaledToFill()
            .clipped()
            .accessibilityHidden(true)
    }
}

struct ArtworkBackdrop: View {
    var dark = false
    var body: some View { KokoGradientBackdrop() }
}

struct KokoTabIcon: View {
    let index: Int
    let selected: Bool
    var body: some View {
        Artwork(sheet: .tabs, tile: index)
            .frame(width: selected ? 34 : 30, height: selected ? 34 : 30)
            .shadow(color: selected ? KokoInk.coral.opacity(0.22) : Color.clear, radius: 7, y: 3)
            .accessibilityHidden(true)
    }
}

struct KokoTabSelectionSurface: View {
    var body: some View {
        KokoControlSurface(highlighted: true)
            .accessibilityHidden(true)
    }
}

struct KokoSocialTag: View {
    let title: String
    var highlighted = false
    var body: some View {
        Text(LocalizedStringKey(title))
            .font(KokoTypography.emphasis(size: 12, relativeTo: .caption))
            .foregroundStyle(highlighted ? KokoInk.onMint : KokoInk.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background {
                KokoControlSurface(highlighted: highlighted)
            }
    }
}

struct KokoAction: View {
    @Environment(\.kokoDialogContent) private var inDialog
    var title: String
    var icon: Int? = nil
    var emphasis = true
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Artwork(sheet: .navigation, tile: icon, ink: emphasis ? KokoInk.onMint : KokoInk.accent).frame(width: 23, height: 23) }
                Text(LocalizedStringKey(title)).font(KokoTypography.emphasis(size: 14, relativeTo: .body))
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(emphasis ? KokoInk.onMint : KokoInk.primary)
            .padding(.horizontal, 18).padding(.vertical, inDialog ? 12 : 14)
            .frame(maxWidth: .infinity, minHeight: inDialog ? 48 : 54)
            .background(KokoControlSurface(highlighted: emphasis))
        }.buttonStyle(KokoPressStyle())
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
        Button(action: action) {
            Artwork(sheet: .navigation, tile: icon).frame(width: 27, height: 27)
                .foregroundStyle(KokoInk.accent).frame(width: 52, height: 52)
                .background(ArtworkSurface())
        }.buttonStyle(KokoPressStyle()).accessibilityLabel(Text(LocalizedStringKey(label)))
    }
}

struct KokoCard<Content: View>: View {
    var tint = 2
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ArtworkSurface(tile: tint))
    }
}

struct KokoField: View {
    let label: String
    @Binding var value: String
    var secure = false
    var keyboard: UIKeyboardType = .default
    var multiline = false
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(LocalizedStringKey(label)).font(KokoTypography.emphasis(size: 12, relativeTo: .caption)).foregroundStyle(KokoInk.secondary)
            Group {
                if secure { SecureField(label, text: $value, prompt: Text(LocalizedStringKey(label)).foregroundColor(KokoInk.secondary)) }
                else { TextField(label, text: $value, prompt: Text(LocalizedStringKey(label)).foregroundColor(KokoInk.secondary), axis: multiline ? .vertical : .horizontal) }
            }
            .textFieldStyle(.plain).keyboardType(keyboard).textInputAutocapitalization(.never).autocorrectionDisabled()
            .font(KokoTypography.medium(size: 15, relativeTo: .body)).foregroundStyle(KokoInk.primary).tint(KokoInk.accent)
            .padding(.horizontal, 16).padding(.vertical, 15).frame(minHeight: 52)
            .background(KokoControlSurface())
        }
    }
}

struct KokoSearchField: View {
    let prompt: String
    @Binding var query: String
    var usesCompactLayout = false
    var body: some View {
        HStack(spacing: 10) {
            Artwork(sheet: .navigation, tile: 4)
                .frame(width: usesCompactLayout ? 21 : 23, height: usesCompactLayout ? 21 : 23)
                .foregroundStyle(KokoInk.accent)
            TextField(prompt, text: $query, prompt: Text(LocalizedStringKey(prompt)).foregroundColor(KokoInk.secondary))
                .textFieldStyle(.plain).font(KokoTypography.medium(size: usesCompactLayout ? 13 : 14, relativeTo: .body))
                .textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.search)
                .accessibilityLabel(Text(LocalizedStringKey(prompt)))
        }.padding(.horizontal, 16).padding(.vertical, usesCompactLayout ? 10 : 14)
            .frame(minHeight: usesCompactLayout ? 46 : 52)
            .background(KokoControlSurface())
    }
}

struct KokoChoiceRail: View {
    let choices: [String]
    @Binding var selection: String
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(choices, id: \.self) { choice in
                    Button { selection = choice } label: {
                        Text(LocalizedStringKey(choice)).font(KokoTypography.emphasis(size: 12, relativeTo: .subheadline))
                            .foregroundStyle(selection == choice ? KokoInk.onMint : KokoInk.secondary)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 16).padding(.vertical, 11).frame(minHeight: 44)
                            .background(KokoControlSurface(highlighted: selection == choice))
                    }.buttonStyle(KokoPressStyle()).accessibilityAddTraits(selection == choice ? .isSelected : [])
                }
            }
        }
    }
}

struct LocalPreviewNote: View {
    var text = "ROOM PREVIEW · SAVED ON THIS DEVICE"
    var body: some View { Text(LocalizedStringKey(text)).font(KokoTypography.medium(size: 10, relativeTo: .caption2)).tracking(0.7).foregroundStyle(KokoInk.secondary).fixedSize(horizontal: false, vertical: true) }
}

struct KokoPage<Content: View>: View {
    @Environment(\.kokoScreenInsets) private var screenInsets
    var title: String? = nil
    var subtitle: String? = nil
    var back: (() -> Void)? = nil
    var openContentOptions: (() -> Void)? = nil
    @ViewBuilder var content: Content
    private var showsHeader: Bool { title != nil || back != nil }
    var body: some View {
        VStack(spacing: 0) {
            if showsHeader {
                HStack(spacing: 12) {
                    if let back { KokoIconAction(icon: 5, label: "Back", action: back) }
                    VStack(alignment: .leading, spacing: 4) {
                        if let title { Text(LocalizedStringKey(title)).font(KokoTypography.heading(size: 26, relativeTo: .title)).foregroundStyle(KokoInk.primary) }
                        if let subtitle { Text(LocalizedStringKey(subtitle)).font(KokoTypography.body(size: 12, relativeTo: .subheadline)).foregroundStyle(KokoInk.secondary) }
                    }.fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if let openContentOptions { KokoIconAction(icon: 11, label: "More", action: openContentOptions) }
                }.padding(.horizontal, 22).padding(.top, screenInsets.top + 8).padding(.bottom, 18)
            }
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) { content }
                    .frame(maxWidth: 620, minHeight: 0, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 22).padding(.top, 2).padding(.bottom, screenInsets.bottom + 24)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
            .scrollDismissesKeyboard(.interactively)
                .padding(.top, showsHeader ? 0 : screenInsets.top + 10)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .clipped()
        .background(ArtworkBackdrop()).foregroundStyle(KokoInk.primary)
    }
}

struct KokoSocialHero: View {
    let eyebrow: String
    let title: String
    let detail: String
    var artwork = 0
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
                Text(LocalizedStringKey(eyebrow))
                    .font(KokoTypography.heading(size: 10, relativeTo: .caption2))
                    .tracking(1.5)
                    .foregroundStyle(KokoInk.coral)
                Text(LocalizedStringKey(title))
                    .font(KokoTypography.heading(size: 23, relativeTo: .title2))
                    .fixedSize(horizontal: false, vertical: true)
                Text(LocalizedStringKey(detail))
                    .font(KokoTypography.body(size: 12, relativeTo: .body))
                    .foregroundStyle(KokoInk.secondary)
                    .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(ArtworkSurface(tile: 3))
    }
}

struct KokoEmpty: View {
    let title: String
    let detail: String
    var art = 2
    var body: some View {
        VStack(spacing: 10) {
            Artwork(sheet: .navigation, tile: 4).frame(width: 30, height: 30)
                .padding(16)
                .background(KokoControlSurface())
            Text(LocalizedStringKey(title)).font(KokoTypography.emphasis(size: 18, relativeTo: .headline))
            Text(LocalizedStringKey(detail)).font(KokoTypography.body(size: 13, relativeTo: .body)).foregroundStyle(KokoInk.secondary)
        }.multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity).padding(22).background(ArtworkSurface())
    }
}

struct KokoSectionTitle: View {
    let title: String
    var detail: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(LocalizedStringKey(title)).font(KokoTypography.heading(size: 20, relativeTo: .title3))
            Spacer(minLength: 0)
            if let detail { Text(LocalizedStringKey(detail)).font(KokoTypography.medium(size: 11, relativeTo: .caption)).foregroundStyle(KokoInk.secondary) }
        }.fixedSize(horizontal: false, vertical: true)
    }
}

struct KokoMenuRow: View {
    @Environment(\.kokoDialogContent) private var inDialog
    let title: String
    var detail: String = ""
    var icon = 3
    var verbatim = false
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if inDialog {
                    Artwork(sheet: .navigation, tile: icon).frame(width: 24, height: 24)
                } else {
                    Artwork(sheet: .navigation, tile: icon).frame(width: 27, height: 27).foregroundStyle(KokoInk.accent)
                        .frame(width: 44, height: 44)
                        .background(KokoInk.panelRaised.opacity(0.72))
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .overlay { RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(KokoInk.line, lineWidth: 1) }
                }
                VStack(alignment: .leading, spacing: 4) {
                    (verbatim ? Text(verbatim: title) : Text(LocalizedStringKey(title)))
                        .font(KokoTypography.emphasis(size: 15, relativeTo: .body))
                    if !detail.isEmpty {
                        (verbatim ? Text(verbatim: detail) : Text(LocalizedStringKey(detail)))
                            .font(KokoTypography.body(size: 12, relativeTo: .caption)).foregroundStyle(KokoInk.secondary).lineLimit(2)
                    }
                }.fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Artwork(sheet: .navigation, tile: 5).rotationEffect(.degrees(180)).frame(width: 17, height: 17).foregroundStyle(KokoInk.coral)
            }.foregroundStyle(KokoInk.primary).padding(14).frame(maxWidth: .infinity, minHeight: inDialog ? 56 : 72, alignment: .leading).background(ArtworkSurface())
        }.buttonStyle(KokoPressStyle())
    }
}

struct KokoToggleRow: View {
    @Environment(\.kokoDialogContent) private var inDialog
    let title: String
    @Binding var enabled: Bool
    var body: some View {
        Button { enabled.toggle() } label: {
            HStack(spacing: 12) {
                Text(LocalizedStringKey(title)).font(KokoTypography.medium(size: 15, relativeTo: .body)).multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if inDialog {
                    if enabled {
                        Image("KokoDialogSuccess").resizable().scaledToFit()
                            .frame(width: 30, height: 24).accessibilityHidden(true)
                    }
                } else {
                    Text(LocalizedStringKey(enabled ? "ON" : "OFF")).font(KokoTypography.heading(size: 11))
                        .foregroundStyle(enabled ? KokoInk.onMint : KokoInk.secondary)
                        .frame(width: 52, height: 38).background(KokoControlSurface(highlighted: enabled))
                }
            }
            .foregroundStyle(inDialog && enabled ? KokoInk.canvas : KokoInk.primary)
            .padding(14).frame(minHeight: 48)
            .background {
                if inDialog { KokoDialogControlSurface(prominent: enabled) }
                else { ArtworkSurface() }
            }
        }.buttonStyle(KokoPressStyle()).accessibilityValue(enabled ? "On" : "Off")
            .accessibilityAddTraits(inDialog && enabled ? .isSelected : [])
    }
}

// Scoped to app-owned dialogs; page controls retain their existing artwork.
private struct KokoDialogContentKey: EnvironmentKey {
    static let defaultValue = false
}
extension EnvironmentValues {
    var kokoDialogContent: Bool {
        get { self[KokoDialogContentKey.self] }
        set { self[KokoDialogContentKey.self] = newValue }
    }
}

enum KokoDialogPresentation: Equatable {
    case compact, selection, connection, safety, success, review

    var illustration: String? {
        switch self {
        case .compact, .selection: nil
        case .connection: "KokoDialogConnection"
        case .safety: "KokoDialogSafety"
        case .success: "KokoDialogSuccess"
        case .review: "KokoDialogReview"
        }
    }
    var width: CGFloat { self == .selection ? 440 : 370 }
}

struct KokoDialogControlSurface: View {
    var prominent = false
    var body: some View {
        Image(prominent ? "KokoDialogPrimary" : "KokoDialogSecondary")
            .resizable().accessibilityHidden(true)
    }
}

struct KokoModal<Content: View>: View {
    @Environment(\.kokoScreenInsets) private var screenInsets
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var textSize
    @AccessibilityFocusState private var headingFocused: Bool
    @State private var appeared = false
    let title: String
    var presentation: KokoDialogPresentation = .compact
    var dismissOnBackdrop = true
    var dismiss: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { viewport in
            ZStack {
                Color.black.opacity(0.72)
                    .ignoresSafeArea(.container)
                    .contentShape(Rectangle())
                    .onTapGesture { if dismissOnBackdrop { dismiss() } }
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 16) {
                    dialogHeading
                    // Short confirmations keep their natural height; long pickers and
                    // enlarged text scroll below a persistent title and close action.
                    ViewThatFits(in: .vertical) {
                        dialogContent.fixedSize(horizontal: false, vertical: true)
                        ScrollView { dialogContent }
                            .scrollDismissesKeyboard(.interactively)
                    }
                }
                .padding(24)
                .frame(maxWidth: presentation.width)
                .background {
                    Image("KokoDialogSurface").resizable().accessibilityHidden(true)
                }
                .padding(.horizontal, viewport.size.width < 360 ? 14 : 22)
                .padding(.top, screenInsets.top + 16)
                .padding(.bottom, screenInsets.bottom + 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared || reduceMotion ? 0 : 10)
            }
        }
        .environment(\.kokoDialogContent, true)
        .foregroundStyle(KokoInk.primary)
        .accessibilityElement(children: .contain).accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, dismiss)
        .onAppear {
            headingFocused = true
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { appeared = true }
        }
    }

    private var dialogContent: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .font(KokoTypography.medium(size: 14, relativeTo: .body))
            .lineSpacing(3)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dialogHeading: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let artwork = presentation.illustration {
                HStack(alignment: .top) {
                    Image(artwork).resizable().scaledToFit()
                        .frame(width: textSize.isAccessibilitySize ? 72 : 112,
                               height: textSize.isAccessibilitySize ? 48 : 72)
                        .accessibilityHidden(true)
                    Spacer(minLength: 8)
                    closeButton
                }
                heading
            } else {
                HStack(alignment: .top, spacing: 10) {
                    heading
                    Spacer(minLength: 0)
                    closeButton
                }
            }
        }
    }
    private var heading: some View {
        Text(LocalizedStringKey(title))
            .font(KokoTypography.heading(size: 23, relativeTo: .title2))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader).accessibilityFocused($headingFocused)
    }
    private var closeButton: some View {
        Button(action: dismiss) {
            Image("KokoDialogClose").resizable().scaledToFit()
                .frame(width: 32, height: 32).frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }.buttonStyle(KokoPressStyle()).accessibilityLabel(Text("Close"))
    }
}
