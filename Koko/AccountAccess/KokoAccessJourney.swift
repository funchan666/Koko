import SwiftUI

@MainActor
final class KokoAccessJourney: ObservableObject {
    @Published private(set) var transitioning = false
    @Published private(set) var transitionCaption = "Preparing your space"
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
                    .rotationEffect(.degrees(turning && !reduceMotion ? 360 : 0))
                Text("koko").font(.custom("AvenirNext-Bold", size: 43)).tracking(-2)
                Text("Tuning in to good company.").font(.custom("AvenirNext-Medium", size: 13)).foregroundStyle(KokoInk.secondary)
            }
        }.onAppear { if !reduceMotion { withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) { turning = true } } }
    }
}

struct KokoAccountLoading: View {
    @EnvironmentObject private var journey: KokoAccessJourney
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ZStack {
            ArtworkBackdrop(dark: true)
            VStack(alignment: .leading, spacing: 20) {
                Artwork(sheet: .arrival, tile: 3).frame(height: 240)
                    .offset(y: reduceMotion ? 0 : CGFloat(3 - journey.progress) * 9)
                    .scaleEffect(reduceMotion ? 1 : 0.92 + Double(journey.progress) * 0.025)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.8), value: journey.progress)
                Text(journey.transitionCaption).font(.custom("AvenirNext-Bold", size: 28))
                Text("A moment to make yourself at home.").font(.custom("AvenirNext-Regular", size: 14)).foregroundStyle(KokoInk.secondary)
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Text(["Your space", "Your company", "Your rhythm"][index])
                            .font(.custom("AvenirNext-DemiBold", size: 10)).padding(.vertical, 12).frame(maxWidth: .infinity)
                            .background(ArtworkSurface(tile: index < journey.progress ? 3 : 5))
                    }
                }.accessibilityHidden(true)
            }.padding(26).background(ArtworkSurface()).frame(maxWidth: 460).padding(22)
        }.accessibilityElement(children: .combine).accessibilityAddTraits(.isModal)
    }
}

struct KokoFirstVisitGuide: View {
    let finished: () -> Void
    @State private var page = 0
    private let titles = ["Find your\nfrequency.", "Good stories\nneed company.", "A little space\nthat's yours."]
    private let descriptions = ["Drop into a listening room. A familiar song can start a new conversation.", "Share a moment, swap a story, and meet people at your own pace. Conversation is always free.", "Bring your interests and make yourself at home. Choose the little details that feel like you."]
    var body: some View {
        KokoPage(title: "koko", subtitle: "GOOD COMPANY, AT YOUR PACE", back: page > 0 ? { page -= 1 } : nil) {
            Artwork(sheet: .arrival, tile: page).frame(height: 300)
            HStack {
                ForEach(0..<3) { index in
                    Text(String(format: "%02d", index + 1)).font(.custom("AvenirNext-DemiBold", size: 12))
                        .frame(width: 44, height: 36).background(ArtworkSurface(tile: index == page ? 3 : 2))
                }
            }.accessibilityLabel("Introduction page \(page + 1) of 3")
            Text(titles[page]).font(.custom("AvenirNext-Bold", size: 36)).lineSpacing(-2)
            Text(descriptions[page]).font(.custom("AvenirNext-Regular", size: 16)).foregroundStyle(KokoInk.secondary)
            KokoAction(title: page == 2 ? "Make myself at home" : "Next", icon: 12) { if page == 2 { finished() } else { page += 1 } }
        }
    }
}
