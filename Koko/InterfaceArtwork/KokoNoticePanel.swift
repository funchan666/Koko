import SwiftUI

struct KokoNoticePanel: View {
    let heading: String
    let message: String
    let dismiss: () -> Void

    var body: some View {
        KokoModal(title: heading, dismissOnBackdrop: false, dismiss: dismiss) {
            Text(LocalizedStringKey(message))
                .foregroundStyle(KokoInk.secondary)
                .fixedSize(horizontal: false, vertical: true)
            KokoAction(title: "Got it", action: dismiss).padding(.top, 4)
        }
    }
}

struct KokoActionFeedbackPanel: View {
    let feedback: KokoActionFeedback
    let dismiss: () -> Void

    var body: some View {
        KokoModal(title: feedback.title,
                  presentation: feedback.awaitingReview ? .review : .success,
                  dismissOnBackdrop: false, dismiss: dismiss) {
            Text(LocalizedStringKey(feedback.message))
                .foregroundStyle(KokoInk.secondary)
                .fixedSize(horizontal: false, vertical: true)
            KokoAction(title: "Got it", action: dismiss).padding(.top, 4)
        }
    }
}
