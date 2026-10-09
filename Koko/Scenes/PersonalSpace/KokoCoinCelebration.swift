import SwiftUI

struct KokoFirstRecordWelcome: View {
    @Environment(\.kokoScreenInsets) private var screenInsets
    @EnvironmentObject private var community: CommunityJournalStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var arrived = false
    @AccessibilityFocusState private var giftFocused: Bool

    var body: some View {
        GeometryReader { viewport in
            ZStack {
                Color.black.opacity(0.66).accessibilityHidden(true)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Text("A little welcome.")
                            .font(.custom("AvenirNext-Bold", size: 25, relativeTo: .title2))
                            .tracking(-0.6)
                            .foregroundStyle(KokoWelcomePalette.paper)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityFocused($giftFocused)
                        Image("KokoFirstHelloGift")
                            .resizable().scaledToFit().frame(width: 142, height: 142)
                            .scaleEffect(reduceMotion || arrived ? 1 : 0.9)
                            .offset(y: reduceMotion || arrived ? 0 : 10)
                            .opacity(reduceMotion || arrived ? 1 : 0)
                            .accessibilityHidden(true)
                            .padding(.top, 12)
                        Text("+\(KokoCoinCatalog.firstVisitGift)")
                            .font(.custom("AvenirNext-Bold", size: 54, relativeTo: .largeTitle))
                            .tracking(-2).monospacedDigit()
                            .foregroundStyle(KokoWelcomePalette.mint)
                            .accessibilityLabel("\(KokoCoinCatalog.firstVisitGift) welcome coins")
                        Text("welcome coins")
                            .font(.custom("AvenirNext-DemiBold", size: 14, relativeTo: .subheadline))
                            .foregroundStyle(KokoWelcomePalette.paper)
                            .accessibilityHidden(true)
                        Text("Already in your wallet.")
                            .font(.custom("AvenirNext-Regular", size: 13, relativeTo: .body))
                            .foregroundStyle(KokoWelcomePalette.quiet)
                            .padding(.top, 6)
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 12) {
                                balanceLabel
                                Spacer(minLength: 8)
                                balanceAmount
                            }
                            VStack(spacing: 6) { balanceLabel; balanceAmount }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background {
                            Image("KokoAccountField").resizable().accessibilityHidden(true)
                        }
                        .padding(.top, 20)
                        KokoWelcomeAction(title: "Let’s explore", primary: true) {
                            community.acknowledgeWelcomeGift()
                        }.padding(.top, 16)
                        Text("Chats and calls are always free.")
                            .font(.custom("AvenirNext-Regular", size: 11, relativeTo: .caption))
                            .foregroundStyle(KokoWelcomePalette.quiet)
                            .padding(.top, 12)
                    }
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(24)
                    .background {
                        Image("KokoConsentSurface")
                            .resizable(capInsets: EdgeInsets(top: 28, leading: 28, bottom: 28, trailing: 28))
                            .accessibilityHidden(true)
                    }
                    .frame(maxWidth: 350)
                    .padding(.horizontal, 24).padding(.vertical, 20)
                    .padding(.top, screenInsets.top).padding(.bottom, screenInsets.bottom)
                    .frame(maxWidth: .infinity, minHeight: viewport.size.height)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { community.acknowledgeWelcomeGift() }
        .onAppear {
            giftFocused = true
            if reduceMotion { arrived = true }
            else { withAnimation(.easeOut(duration: 0.5)) { arrived = true } }
        }
    }

    private var balanceLabel: some View {
        Text("Your balance")
            .font(.custom("AvenirNext-Medium", size: 12, relativeTo: .subheadline))
            .foregroundStyle(KokoWelcomePalette.quiet)
            .fixedSize(horizontal: true, vertical: false)
    }
    private var balanceAmount: some View {
        Text("\(community.coinBalance.formatted()) coins")
            .font(.custom("AvenirNext-DemiBold", size: 14, relativeTo: .body))
            .foregroundStyle(KokoWelcomePalette.paper).monospacedDigit()
            .fixedSize(horizontal: true, vertical: false)
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
