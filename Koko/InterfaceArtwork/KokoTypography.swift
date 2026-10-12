import SwiftUI

/// Fonts are bundled under Resources/Fonts and registered by UIAppFonts.
/// PostScript names come from the original, unmodified TTF name tables.
/// Missing scripts (including Chinese/Japanese) use iOS's on-device glyph fallback.
/// Never fetch fonts at runtime. Keep handwriting out of controls and long text.
enum KokoTypography {
    static func body(size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("NunitoSans-Regular", size: size, relativeTo: style)
    }
    static func medium(size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("NunitoSans-Medium", size: size, relativeTo: style)
    }
    static func emphasis(size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("NunitoSans-SemiBold", size: size, relativeTo: style)
    }
    static func heading(size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Outfit-Bold", size: size, relativeTo: style)
    }
    // Use only when the caller already scales its size with @ScaledMetric.
    static func heading(scaledSize: CGFloat) -> Font {
        .custom("Outfit-Bold", fixedSize: scaledSize)
    }
    static func handwritten(size: CGFloat, relativeTo style: Font.TextStyle = .title2) -> Font {
        .custom("Caveat-Bold", size: size, relativeTo: style)
    }
}
