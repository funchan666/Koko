import SwiftUI

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
    static func heading(scaledSize: CGFloat) -> Font {
        .custom("Outfit-Bold", fixedSize: scaledSize)
    }
    static func handwritten(size: CGFloat, relativeTo style: Font.TextStyle = .title2) -> Font {
        .custom("Caveat-Bold", size: size, relativeTo: style)
    }
}
