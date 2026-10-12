import SwiftUI

/// A restrained decorative breath for existing original signal artwork.
/// This never represents microphone levels, viewer activity, or broadcast connectivity.
struct KokoRoomSignalBreathing: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    func body(content: Content) -> some View {
        let animates = isVisible && scenePhase == .active && !reduceMotion
        TimelineView(.animation(minimumInterval: 1.0 / 24, paused: !animates)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.4) / 3.4
            let breath = (sin(phase * .pi * 2) + 1) / 2
            content
                .scaleEffect(animates ? 0.98 + breath * 0.04 : 1)
                .opacity(animates ? 0.86 + breath * 0.14 : 1)
        }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }
}

/// Identifies the room category while explicitly describing the supplied recording.
/// A live status must come from a connected broadcasting service, never the room type.
struct KokoBroadcastRoomBadge: View {
    let hasRecordedPreview: Bool
    var showsStatusDetail = true
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Live room")
                .font(KokoTypography.heading(size: 11, relativeTo: .caption))
            if showsStatusDetail {
                Text(LocalizedStringKey(hasRecordedPreview ? "Recorded preview" : "Not broadcasting"))
                    .font(KokoTypography.emphasis(size: 8.5, relativeTo: .caption2))
            }
        }
        .foregroundStyle(KokoInk.canvas)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(width: showsStatusDetail ? 76 : 64, alignment: showsStatusDetail ? .leading : .center)
        .padding(.leading, 33).padding(.trailing, 9)
        .frame(height: showsStatusDetail ? 40 : 32)
        .background {
            Image("KokoBroadcastRoomBadge")
                .resizable().scaledToFit().accessibilityHidden(true)
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(LocalizedStringKey(hasRecordedPreview ? "Live room · recorded preview" : "Live room · not broadcasting")))
    }
}
