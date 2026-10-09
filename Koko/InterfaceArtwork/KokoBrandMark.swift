import SwiftUI

/// The supplied Live artwork is the single Koko brand mark used in launch and loading surfaces.
struct KokoBrandMark: View {
    var size: CGFloat = 148
    var body: some View {
        Image("KokoAppIcon")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.18, style: .continuous))
            .accessibilityLabel("Koko Live")
    }
}

struct KokoBrandLoading: View {
    let caption: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false

    var body: some View {
        VStack(spacing: 20) {
            KokoBrandMark(size: 156)
                .scaleEffect(reduceMotion || !breathe ? 1 : 1.035)
                .opacity(reduceMotion || !breathe ? 1 : 0.82)
            Text(caption.uppercased())
                .font(.custom("AvenirNext-Bold", size: 11))
                .tracking(2.4)
                .foregroundStyle(KokoWelcomePalette.mint)
            Text("•••")
                .font(.custom("AvenirNext-Bold", size: 20))
                .tracking(6)
                .foregroundStyle(KokoWelcomePalette.paper)
                .opacity(reduceMotion || !breathe ? 0.45 : 1)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { breathe = true }
        }
        .onChange(of: reduceMotion) { reduced in breathe = !reduced }
    }
}
