import SwiftUI

private struct KokoScreenInsetsKey: EnvironmentKey {
    static let defaultValue = EdgeInsets()
}

extension EnvironmentValues {
    var kokoScreenInsets: EdgeInsets {
        get { self[KokoScreenInsetsKey.self] }
        set { self[KokoScreenInsetsKey.self] = newValue }
    }
}

/// Every app-owned screen gets the whole container. Insets protect individual
/// controls and scroll endpoints, rather than reserving unpainted screen bands.
struct KokoScreenCanvas<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        GeometryReader { viewport in
            let measured = viewport.safeAreaInsets
            let controls = EdgeInsets(top: measured.top, leading: measured.leading,
                                      bottom: measured.bottom > 100 ? 0 : measured.bottom,
                                      trailing: measured.trailing)
            content
                .environment(\.kokoScreenInsets, controls)
                .ignoresSafeArea(.container, edges: .all)
        }
    }
}
