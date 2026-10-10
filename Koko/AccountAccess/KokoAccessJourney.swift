import SwiftUI

@MainActor
final class KokoAccessJourney: ObservableObject {
    @Published var usesDarkWelcomeAppearance = false
    @Published var usesDarkProfileAppearance = false
    @Published var showsPolicyReader = false
    @Published private(set) var transitioning = false
    @Published private(set) var transitionCaption = "Getting ready…"
    @Published private(set) var progress = 0

    func enter(caption: String, operation: @escaping @MainActor () async -> Void) {
        guard !transitioning else { return }
        transitioning = true; transitionCaption = caption; progress = 0
        Task {
            // An intentional 3.6 s entry sequence requested for Koko, not a simulated network request.
            do {
                for step in 1...3 {
                    try await Task.sleep(nanoseconds: 1_200_000_000)
                    progress = step
                }
                await operation()
            } catch { }
            transitioning = false; progress = 0
        }
    }
}

struct KokoLaunchLoading: View {
    var body: some View {
        KokoLoadingSurface(caption: "Tuning in")
    }
}

struct KokoAccountLoading: View {
    @EnvironmentObject private var journey: KokoAccessJourney
    @AccessibilityFocusState private var loadingFocused: Bool

    var body: some View {
        KokoLoadingSurface(caption: journey.transitionCaption)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(journey.transitionCaption)
        .accessibilityAddTraits(.isModal)
        .accessibilityFocused($loadingFocused)
        .onAppear {
            loadingFocused = true
        }
    }
}

/// Background artwork never participates in measuring the loading content.
/// The viewport comes from KokoScreenCanvas, so both waiting screens stay centered.
private struct KokoLoadingSurface: View {
    let caption: String
    @Environment(\.kokoScreenInsets) private var screenInsets

    var body: some View {
        GeometryReader { viewport in
            let verticalPadding = max(screenInsets.top, screenInsets.bottom) + 24
            ScrollView(showsIndicators: false) {
                KokoBrandLoading(caption: caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.vertical, verticalPadding)
                    .frame(width: viewport.size.width, alignment: .center)
                    .frame(minHeight: viewport.size.height, alignment: .center)
            }
            .frame(width: viewport.size.width, height: viewport.size.height)
            .background {
                KokoGradientBackdrop()
                    .frame(width: viewport.size.width, height: viewport.size.height)
                    .clipped()
            }
            .clipped()
        }
        .foregroundStyle(KokoInk.primary)
    }
}
