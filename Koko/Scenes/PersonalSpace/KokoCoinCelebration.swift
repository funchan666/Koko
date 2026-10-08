import SwiftUI

struct KokoFirstRecordWelcome: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var arrived = false
    var body: some View {
        ZStack {
            ArtworkBackdrop(dark: true)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("KOKO · YOUR FIRST RECORD").font(.custom("AvenirNext-DemiBold", size: 11)).tracking(1.3)
                        Spacer()
                        KokoIconAction(icon: 6, label: "Close welcome") { community.acknowledgeWelcomeGift() }
                    }
                    Image("KokoFirstRecord").resizable().scaledToFit().frame(maxWidth: .infinity).frame(height: 265)
                        .scaleEffect(arrived ? 1 : 0.86).rotationEffect(.degrees(arrived ? 0 : -9))
                        .offset(y: arrived ? 0 : 22).opacity(arrived ? 1 : 0)
                        .accessibilityHidden(true)
                    Text("You're part\nof the rhythm.").font(.custom("AvenirNext-Bold", size: 35)).lineSpacing(-3)
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("+\(KokoCoinCatalog.firstVisitGift)").font(.custom("AvenirNext-Bold", size: 54)).monospacedDigit()
                        Text("WELCOME COINS").font(.custom("AvenirNext-DemiBold", size: 10)).tracking(1)
                    }
                    Text("A first little gift from Koko. Your coins are already in your wallet, ready for a keepsake or a kind gesture.").font(.custom("AvenirNext-Regular", size: 15))
                    Text("Current balance · \(community.coinBalance) coins").font(.custom("AvenirNext-DemiBold", size: 13))
                    KokoAction(title: "Find my people", icon: 1) { community.acknowledgeWelcomeGift() }
                    Text("Your conversations are always free.").font(.custom("AvenirNext-Medium", size: 12)).foregroundStyle(KokoInk.secondary)
                }.padding(26).background(ArtworkSurface()).frame(maxWidth: 480).padding(22).frame(maxWidth: .infinity)
            }
        }.onAppear {
            if reduceMotion { arrived = true }
            else { withAnimation(.spring(response: 0.85, dampingFraction: 0.78)) { arrived = true } }
        }.accessibilityAddTraits(.isModal)
    }
}

struct KokoCoinSpendConfirmation: View {
    @EnvironmentObject private var community: CommunityJournalStore
    let request: CoinSpendRequest
    var body: some View {
        if let item = KokoCommunity.keepsakes.first(where: { $0.id == request.keepsakeID }) {
            let total = item.tokenCost * request.quantity
            KokoModal(title: "A little gesture, on purpose", dismiss: { community.coinSpendRequest = nil }) {
                Artwork(sheet: .collection, tile: item.artworkTile).frame(height: 150)
                Text(item.keepsakeName + " ×\(request.quantity)").font(.custom("AvenirNext-Bold", size: 24))
                Text(request.roomID == nil ? "This item goes into your backpack." : "This is an optional gift for a local room. No message, call or conversation requires it.")
                KokoCard(tint: 3) {
                    VStack(spacing: 12) {
                        balanceLine("Available", community.coinBalance)
                        balanceLine("Spend", total)
                        balanceLine("After this gesture", max(0, community.coinBalance - total))
                    }
                }
                KokoAction(title: "Confirm · spend \(total) coins", icon: 8) { community.confirmCoinSpend() }
                KokoAction(title: "Keep my coins", emphasis: false) { community.coinSpendRequest = nil }
            }
        }
    }
    private func balanceLine(_ label: String, _ amount: Int) -> some View {
        HStack { Text(label).font(.custom("AvenirNext-Regular", size: 13)); Spacer(); Text(amount.formatted()).font(.custom("AvenirNext-Bold", size: 20)).monospacedDigit() }
    }
}
