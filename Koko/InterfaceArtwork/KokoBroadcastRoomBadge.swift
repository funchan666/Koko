import SwiftUI

/// Identifies the room category while explicitly describing the supplied recording.
/// A live status must come from a connected broadcasting service, never the room type.
struct KokoBroadcastRoomBadge: View {
    let hasRecordedPreview: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Live room")
                .font(KokoTypography.heading(size: 11, relativeTo: .caption))
            Text(LocalizedStringKey(hasRecordedPreview ? "Recorded preview" : "Not broadcasting"))
                .font(KokoTypography.emphasis(size: 8.5, relativeTo: .caption2))
        }
        .foregroundStyle(KokoInk.canvas)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(width: 76, alignment: .leading)
        .padding(.leading, 33).padding(.trailing, 9)
        .frame(height: 40)
        .background {
            Image("KokoBroadcastRoomBadge")
                .resizable().scaledToFit().accessibilityHidden(true)
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(LocalizedStringKey(hasRecordedPreview ? "Live room · recorded preview" : "Live room · not broadcasting")))
    }
}
