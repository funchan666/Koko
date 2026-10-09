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
                        Text(heading)
                            .font(.custom("AvenirNext-Bold", size: 25, relativeTo: .title2))
                            .tracking(-0.6)
                            .foregroundStyle(KokoWelcomePalette.paper)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        Text(message)
                            .font(.custom("AvenirNext-Regular", size: 15, relativeTo: .body))
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
