import SwiftUI

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
