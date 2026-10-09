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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var turning = false
    var body: some View {
        ZStack {
            ArtworkBackdrop()
            VStack(spacing: 24) {
                Artwork(sheet: .arrival, tile: 0).frame(width: 145, height: 145)
                    .opacity(turning && !reduceMotion ? 0.68 : 1)
                Text("koko").font(.custom("AvenirNext-Bold", size: 43)).tracking(-2)
                Text("Tuning in to good company.").font(.custom("AvenirNext-Medium", size: 13)).foregroundStyle(KokoInk.secondary)
            }
        }.foregroundStyle(KokoInk.primary)
        .onAppear { if !reduceMotion { withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { turning = true } } }
    }
}

struct KokoAccountLoading: View {
    @EnvironmentObject private var journey: KokoAccessJourney
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.kokoScreenInsets) private var screenInsets
    @State private var gentlyFloating = false
    @AccessibilityFocusState private var loadingFocused: Bool

    var body: some View {
        ZStack {
            KokoWelcomePalette.backdrop
            GeometryReader { viewport in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        Image("KokoConversationArrival")
                            .resizable().scaledToFit()
                            .frame(width: min(200, max(120, viewport.size.width - 80)), height: 200)
                            .scaleEffect(reduceMotion || !gentlyFloating ? 1 : 1.035)
                            .offset(y: reduceMotion || !gentlyFloating ? 0 : -6)
                            .animation(reduceMotion ? nil : .easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: gentlyFloating)
                            .accessibilityHidden(true)
                        Text(journey.transitionCaption)
                            .font(.custom("AvenirNext-DemiBold", size: 21, relativeTo: .title3))
                            .foregroundStyle(KokoWelcomePalette.paper)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
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
            gentlyFloating = !reduceMotion
            loadingFocused = true
        }
        .onChange(of: reduceMotion) { reduced in gentlyFloating = !reduced }
    }
}
