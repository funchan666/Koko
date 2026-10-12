import SwiftUI

/// App feedback only. Apple authorization, permission and purchase sheets stay native.
struct KokoNoticePanel: View {
    let heading: String
    let message: String
    let dismiss: () -> Void
    @Environment(\.kokoScreenInsets) private var screenInsets
    @AccessibilityFocusState private var messageFocused: Bool

    var body: some View {
        GeometryReader { viewport in
            ZStack {
                Color.black.opacity(0.62)
                    .ignoresSafeArea(.container)
                    .accessibilityHidden(true)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(LocalizedStringKey(heading))
                            .font(KokoTypography.heading(size: 25, relativeTo: .title2))
                            .tracking(-0.6)
                            .foregroundStyle(KokoWelcomePalette.paper)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        Text(LocalizedStringKey(message))
                            .font(KokoTypography.body(size: 15, relativeTo: .body))
                            .foregroundStyle(KokoWelcomePalette.quiet)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 12)
                            .accessibilityFocused($messageFocused)
                        KokoWelcomeAction(title: "Got it", primary: true, action: dismiss)
                            .padding(.top, 24)
                    }
                    .padding(28)
                    .background {
                        Image("KokoConsentSurface")
                            .resizable(capInsets: EdgeInsets(top: 28, leading: 28, bottom: 28, trailing: 28))
                            .accessibilityHidden(true)
                    }
                    .frame(maxWidth: 360)
                    .padding(.horizontal, 24).padding(.vertical, 24)
                    .padding(.top, screenInsets.top).padding(.bottom, screenInsets.bottom)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: viewport.size.height, alignment: .center)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, dismiss)
        .onAppear { messageFocused = true }
    }
}

struct KokoActionFeedbackPanel: View {
    let feedback: KokoActionFeedback
    let dismiss: () -> Void
    @Environment(\.kokoScreenInsets) private var insets
    @AccessibilityFocusState private var focused: Bool
    @ScaledMetric(relativeTo: .body) private var artworkHeader: CGFloat = 190
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.68).accessibilityHidden(true)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(LocalizedStringKey(feedback.awaitingReview ? "YOUR MOMENT" : "YOUR SPACE"))
                            .font(KokoTypography.emphasis(size: 11)).tracking(1.8)
                        Text(LocalizedStringKey(feedback.title))
                            .font(KokoTypography.heading(size: 27, relativeTo: .title2))
                            .accessibilityAddTraits(.isHeader).accessibilityFocused($focused)
                        Text(LocalizedStringKey(feedback.message))
                            .font(KokoTypography.medium(size: 15, relativeTo: .body))
                            .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                        Button(action: dismiss) {
                            Text("Got it").font(KokoTypography.emphasis(size: 16))
                                .foregroundStyle(KokoInk.paper).frame(maxWidth: .infinity, minHeight: 52)
                                .background(Image("KokoProfileQuietSurface").resizable())
                        }.buttonStyle(KokoPressStyle()).padding(.top, 8)
                    }
                    .foregroundStyle(KokoInk.canvas).padding(.horizontal, 30)
                    .padding(.top, artworkHeader).padding(.bottom, 38)
                    .frame(maxWidth: 360, minHeight: 560, alignment: .topLeading)
                    .background(Image(feedback.awaitingReview ? "KokoReviewReceiptSurface" : "KokoSafetyReceiptSurface").resizable())
                    .padding(.horizontal, 22).padding(.top, insets.top + 20).padding(.bottom, insets.bottom + 20)
                    .frame(maxWidth: .infinity).frame(minHeight: geometry.size.height)
                }
            }
        }.accessibilityElement(children: .contain).accessibilityAddTraits(.isModal)
            .accessibilityAction(.escape, dismiss).onAppear { focused = true }
    }
}
