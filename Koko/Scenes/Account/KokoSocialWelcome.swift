import SwiftUI
import UIKit

enum KokoWelcomePalette {
    static let backdrop = Color(red: 19 / 255, green: 42 / 255, blue: 38 / 255)
    static let mint = Color(red: 185 / 255, green: 237 / 255, blue: 206 / 255)
    static let paper = Color(red: 246 / 255, green: 249 / 255, blue: 243 / 255)
    static let quiet = Color(red: 180 / 255, green: 202 / 255, blue: 193 / 255)
}

// Crops the original generated atlas. No icons, button skins or decorative artwork are drawn in code.
@MainActor
private enum KokoWelcomeArtwork {
    private static var prepared: [Int: UIImage] = [:]
    private static var entrySkins: [KokoWelcomeEntryStyle: UIImage] = [:]

    static func entrySkin(_ style: KokoWelcomeEntryStyle) -> UIImage {
        if let image = entrySkins[style] { return image }
        guard let source = UIImage(named: "KokoWelcomeEntryButtons")?.cgImage else { return UIImage() }
        let region: CGRect
        switch style {
        case .email: region = CGRect(x: 58, y: 218, width: 1140, height: 240)
        case .apple: region = CGRect(x: 58, y: 528, width: 1140, height: 232)
        case .registration: region = CGRect(x: 58, y: 832, width: 1140, height: 232)
        }
        let scale = CGFloat(source.width) / 1254
        guard let cropped = source.cropping(to: CGRect(x: region.minX * scale, y: region.minY * scale,
                                                      width: region.width * scale, height: region.height * scale)) else { return UIImage() }
        // Keep the illustrated end caps at their intended size while the quiet center stretches.
        let image = UIImage(cgImage: cropped, scale: 4 * scale, orientation: .up)
        entrySkins[style] = image
        return image
    }
    static func control(_ index: Int) -> UIImage {
        if let image = prepared[index] { return image }
        guard let source = UIImage(named: "KokoWelcomeControls")?.cgImage else { return UIImage() }
        let regions = [
            CGRect(x: 52, y: 273, width: 559, height: 195),
            CGRect(x: 639, y: 269, width: 570, height: 201),
            CGRect(x: 225, y: 769, width: 218, height: 217),
            CGRect(x: 816, y: 776, width: 210, height: 209)
        ]
        let region = regions[min(max(index, 0), 3)]
        let scale = CGFloat(source.width) / 1254
        guard let cropped = source.cropping(to: CGRect(x: region.minX * scale, y: region.minY * scale, width: region.width * scale, height: region.height * scale)) else { return UIImage() }
        let image = UIImage(cgImage: cropped, scale: 3, orientation: .up)
        prepared[index] = image
        return image
    }
}

struct KokoSocialWelcome: View {
    @Environment(\.kokoScreenInsets) private var screenInsets
    @Binding var agreed: Bool
    let authorizing: Bool
    let logIn: () -> Void
    let appleSignIn: () -> Void
    let signUp: () -> Void
    let openPolicy: (KokoLegalDocument) -> Void
    @ScaledMetric(relativeTo: .largeTitle) private var headlineSize: CGFloat = 36

    var body: some View {
        GeometryReader { geometry in
            // Reserve room for native text and actions instead of stretching a spacer between them.
            let portraitExtent = min(geometry.size.width, 440, max(250, geometry.size.height - 445))
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Image("KokoWelcomeCompanyCutout")
                        .resizable().scaledToFit()
                        .frame(width: portraitExtent, height: portraitExtent)
                        .accessibilityHidden(true)
                    (Text("Good company.\n").foregroundColor(KokoWelcomePalette.paper)
                     + Text("Starts here.").foregroundColor(KokoWelcomePalette.mint))
                        .font(.custom("AvenirNext-Bold", size: min(headlineSize, 64)))
                        .tracking(-1.3)
                        .lineSpacing(-2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.horizontal, 30)
                        // The artwork deliberately reserves its bottom fifth for this headline.
                        .padding(.top, -portraitExtent * 0.16)
                    VStack(spacing: 10) {
                        KokoWelcomeEntryButton(title: "Log in", style: .email, action: logIn)
                        KokoWelcomeEntryButton(title: authorizing ? "Waiting for Apple…" : "Continue with Apple",
                                               style: .apple, action: appleSignIn)
                        KokoWelcomeEntryButton(title: "Create account", style: .registration, action: signUp)
                    }.padding(.horizontal, 28).padding(.top, 22)
                    KokoEntryAgreement(agreed: $agreed, openPolicy: openPolicy)
                        .padding(.horizontal, 22).padding(.top, 16).padding(.bottom, 12)
                }.padding(.top, screenInsets.top + 8).padding(.bottom, screenInsets.bottom)
                    .frame(maxWidth: 500)
                    .frame(minHeight: geometry.size.height, alignment: .center)
                    .frame(maxWidth: .infinity)
            }.background {
                KokoGradientBackdrop()
                Image("KokoSocialAtlas")
                    .resizable().scaledToFit()
                    .frame(width: 260, height: 196)
                    .opacity(0.08)
                    .offset(x: 88, y: -18)
                    .accessibilityHidden(true)
            }
        }.foregroundStyle(KokoWelcomePalette.paper)
    }

}

private enum KokoWelcomeEntryStyle: Hashable {
    case email, apple, registration
}

private struct KokoWelcomeEntryButton: View {
    let title: String
    let style: KokoWelcomeEntryStyle
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.custom("AvenirNext-DemiBold", size: 16, relativeTo: .body))
                .foregroundStyle(style == .registration ? KokoWelcomePalette.mint : KokoWelcomePalette.backdrop)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(style == .apple ? .center : .leading)
                .padding(.leading, 24)
                .padding(.trailing, style == .apple ? 24 : 68)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, minHeight: 58, alignment: style == .apple ? .center : .leading)
                .background {
                    Image(uiImage: KokoWelcomeArtwork.entrySkin(style))
                        .resizable(capInsets: EdgeInsets(top: 22, leading: 24, bottom: 22, trailing: 56), resizingMode: .stretch)
                        .accessibilityHidden(true)
                }
        }.buttonStyle(KokoPressStyle())
    }
}

struct KokoEntryAgreement: View {
    @Binding var agreed: Bool
    let openPolicy: (KokoLegalDocument) -> Void
    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            Button { agreed.toggle() } label: {
                Image(uiImage: KokoWelcomeArtwork.control(agreed ? 3 : 2))
                    .resizable().scaledToFit().frame(width: 19, height: 19)
                    .frame(width: 44, height: 44)
            }.buttonStyle(KokoPressStyle())
                .accessibilityLabel("Agree to Terms of Service and Privacy Policy")
                .accessibilityValue(agreed ? "Selected" : "Not selected")
                .accessibilityAddTraits(agreed ? .isSelected : [])
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 4) {
                    agreementPrefix
                    policyLink(.terms, label: "Terms")
                    Text("&").foregroundStyle(KokoWelcomePalette.quiet)
                    policyLink(.privacy, label: "Privacy")
                }.fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: 0) {
                    agreementPrefix
                    HStack(spacing: 4) {
                        policyLink(.terms, label: "Terms")
                        Text("&").foregroundStyle(KokoWelcomePalette.quiet)
                        policyLink(.privacy, label: "Privacy")
                    }
                }
            }.font(.custom("AvenirNext-Regular", size: 12, relativeTo: .caption))
        }.frame(maxWidth: .infinity)
    }
    private var agreementPrefix: some View {
        Text("I agree to").foregroundStyle(KokoWelcomePalette.quiet).fixedSize(horizontal: false, vertical: true)
    }
    private func policyLink(_ document: KokoLegalDocument, label: String) -> some View {
        Button { openPolicy(document) } label: {
            Text(label).underline().font(.custom("AvenirNext-DemiBold", size: 12, relativeTo: .caption))
                .foregroundStyle(KokoWelcomePalette.mint).fixedSize()
                .frame(minWidth: 44, minHeight: 44)
        }.buttonStyle(KokoPressStyle()).accessibilityLabel(document.title)
    }
}

struct KokoWelcomeAction: View {
    let title: String
    let primary: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.custom("AvenirNext-DemiBold", size: 16, relativeTo: .body))
                .foregroundStyle(primary ? KokoWelcomePalette.backdrop : KokoWelcomePalette.paper)
                .padding(.horizontal, 20).padding(.vertical, primary ? 16 : 12)
                .frame(maxWidth: .infinity, minHeight: primary ? 56 : 48)
                .background {
                    if primary {
                        Image(uiImage: KokoWelcomeArtwork.control(0))
                            .resizable(capInsets: EdgeInsets(top: 22, leading: 22, bottom: 22, trailing: 22), resizingMode: .stretch)
                            .accessibilityHidden(true)
                    }
                }
        }.buttonStyle(KokoPressStyle())
    }
}
