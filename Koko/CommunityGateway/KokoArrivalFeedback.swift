import SwiftUI

struct KokoArrivalFeedback: View {
    @EnvironmentObject private var arrival: KokoArrivalCoordinator
    var body: some View {
        VStack(spacing: 8) {
            if arrival.checkingEntrances { Text("Finding your way in…") }
            if let caption = arrival.caption { Text(caption).accessibilityAddTraits(.updatesFrequently) }
            if let failure = arrival.failure {
                Text(failure).fixedSize(horizontal: false, vertical: true)
            }
        }.font(KokoTypography.body(size: 14)).foregroundStyle(KokoWelcomePalette.quiet)
            .frame(maxWidth: .infinity).multilineTextAlignment(.center)
    }
}

struct KokoRoomRecoveryPanel: View {
    @EnvironmentObject private var arrival: KokoArrivalCoordinator
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text(arrival.caption ?? "This room is unavailable.")
                .font(KokoTypography.emphasis(size: 18)).multilineTextAlignment(.center)
            KokoWelcomeAction(title: "Try again", primary: true, action: arrival.retryRoom)
            KokoWelcomeAction(title: "Back to welcome", primary: false, action: arrival.logout)
            Spacer()
        }.padding(28).background(ArtworkBackdrop())
    }
}
