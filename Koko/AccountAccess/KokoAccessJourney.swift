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
        ZStack {
            KokoGradientBackdrop()
            KokoBrandLoading(caption: "Tuning in")
        }.foregroundStyle(KokoInk.primary)
    }
}

struct KokoAccountLoading: View {
    @EnvironmentObject private var journey: KokoAccessJourney
    @Environment(\.kokoScreenInsets) private var screenInsets
    @AccessibilityFocusState private var loadingFocused: Bool

    var body: some View {
        ZStack {
            KokoGradientBackdrop()
            GeometryReader { viewport in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        KokoBrandLoading(caption: journey.transitionCaption)
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, screenInsets.top + 24)
                    .padding(.bottom, screenInsets.bottom + 24)
                    .frame(maxWidth: .infinity, minHeight: viewport.size.height)
                }.accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(journey.transitionCaption)
        .accessibilityAddTraits(.isModal)
        .accessibilityFocused($loadingFocused)
        .onAppear {
            loadingFocused = true
        }
    }
}
