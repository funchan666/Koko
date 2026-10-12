import SwiftUI

/// The user's supplied icon is shared by the app icon and every in-app brand placement.
struct KokoBrandMark: View {
    var size: CGFloat = 148
    var body: some View {
        Image("KokoBrandMark")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel("Koko Live")
    }
}

struct KokoBrandLoading: View {
    let caption: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var animationOrigin = Date()

    private var loadingLight: some View {
        Image("KokoLoadingLight")
            .resizable()
            .scaledToFit()
            .frame(width: 28, height: 28)
            .accessibilityHidden(true)
    }

    var body: some View {
        ZStack {
            // Keep the icon itself at the exact window center, matching the launch storyboard.
            KokoBrandMark(size: 160)
            Group {
                if reduceMotion || scenePhase != .active {
                    loadingLight
                } else {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                        loadingLight.rotationEffect(.degrees(
                            timeline.date.timeIntervalSince(animationOrigin)
                                .truncatingRemainder(dividingBy: 1.4) / 1.4 * 360
                        ))
                    }
                }
            }
            .offset(y: 118)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(LocalizedStringKey(caption)))
    }
}
