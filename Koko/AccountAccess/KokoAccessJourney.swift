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
    var captionOverride: String? = nil
    @AccessibilityFocusState private var loadingFocused: Bool
    private var caption: String { captionOverride ?? journey.transitionCaption }

    var body: some View {
        KokoLoadingSurface(caption: caption)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(LocalizedStringKey(caption)))
        .accessibilityAddTraits(.isModal)
        .accessibilityFocused($loadingFocused)
        .onAppear {
            loadingFocused = true
        }
    }
}

private struct KokoLoadingSurface: View {
    let caption: String

    var body: some View {
        GeometryReader { viewport in
            KokoBrandLoading(caption: caption)
                .frame(width: viewport.size.width, height: viewport.size.height)
                .background(Color("KokoLaunchBackdrop"))
        }
    }
}
