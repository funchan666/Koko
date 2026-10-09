import SwiftUI

struct KokoWalletView: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @EnvironmentObject private var purchases: KokoAppleCoinPurchases
    @State private var walletSection = "Coin packs"
    private var busy: Bool { purchases.purchasingProductID != nil || purchases.recoveringOrders }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // The balance remains visible while the collection scrolls.
                HStack(spacing: 12) {
                    KokoIconAction(icon: 5, label: "Back", action: navigation.back)
                    Text("Your coins").font(.custom("AvenirNext-Bold", size: 24))
                    Spacer(minLength: 4)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(community.coinBalance.formatted()).font(.custom("AvenirNext-Bold", size: 24)).monospacedDigit()
                        Text("AVAILABLE").font(.custom("AvenirNext-DemiBold", size: 9)).tracking(1)
                    }.accessibilityElement(children: .combine).accessibilityLabel("Balance: \(community.coinBalance) coins")
                }.padding(.horizontal, 20).padding(.vertical, 10)
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        walletIntroduction
                        if let shortfall = community.coinShortfall {
                            KokoCard(tint: 3) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("A little more for \(shortfall.purpose)").font(.custom("AvenirNext-Bold", size: 18))
                                    Text("Cost: \(shortfall.requiredCoins) coins. You need \(max(0, shortfall.requiredCoins - community.coinBalance) + community.coinAdjustmentDue) more.")
                                    Text("After adding coins, return to the item and confirm it again. Nothing is spent automatically.").font(.custom("AvenirNext-Regular", size: 12))
                                    Button("Dismiss") { community.coinShortfall = nil }.font(.custom("AvenirNext-DemiBold", size: 13)).buttonStyle(.plain).padding(.vertical, 8)
                                }
                            }
                        }
                        if community.coinAdjustmentDue > 0 {
                            Text("Refund adjustment: \(community.coinAdjustmentDue) coins. New credits settle this amount before becoming available.")
                                .font(.custom("AvenirNext-Medium", size: 13)).foregroundStyle(KokoInk.warning)
                        }
                        KokoChoiceRail(choices: ["Coin packs", "Ways to use", "History"], selection: $walletSection)
                        switch walletSection {
                        case "Ways to use": spendingGuide
                        case "History": walletHistory
                        default: coinPacks
                        }
                    }.frame(maxWidth: 680).frame(maxWidth: .infinity).padding(22)
                }
            }.background(ArtworkBackdrop())
        }.task { community.prepareCoinWallet() }
    }

    private var walletIntroduction: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Small gestures.\nYour own rhythm.").font(.custom("AvenirNext-Bold", size: 27))
                Text("A little appreciation, a touch of you.").font(.custom("AvenirNext-Regular", size: 13)).foregroundStyle(KokoInk.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Image("KokoFirstRecord").resizable().scaledToFit().frame(width: 135, height: 165).accessibilityHidden(true)
        }
    }

    private var coinPacks: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose your collection").font(.custom("AvenirNext-Bold", size: 22))
            Text("Prices below are US reference prices until you tap Buy. Apple then confirms availability and your storefront price before payment.")
                .font(.custom("AvenirNext-Regular", size: 12)).foregroundStyle(KokoInk.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(KokoCoinCatalog.packs) { pack in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(pack.collectionTitle).font(.custom("AvenirNext-DemiBold", size: 12)).foregroundStyle(KokoInk.secondary)
                        Text(pack.coinQuantity.formatted()).font(.custom("AvenirNext-Bold", size: 28)).minimumScaleFactor(0.75).lineLimit(1)
                        Text("Koko coins").font(.custom("AvenirNext-Medium", size: 11))
                        Text(purchases.localizedPrices[pack.id] ?? pack.referencePriceLabel).font(.custom("AvenirNext-DemiBold", size: 16))
                        KokoAction(title: purchases.purchasingProductID == pack.id ? "Connecting…" : "Buy") {
                            Task { await purchases.purchase(pack) }
                        }.disabled(busy).opacity(busy && purchases.purchasingProductID != pack.id ? 0.5 : 1)
                    }.padding(15).frame(maxWidth: .infinity, alignment: .leading).background(ArtworkSurface())
                }
            }
            if !purchases.phaseDescription.isEmpty {
                Text(purchases.phaseDescription).font(.custom("AvenirNext-DemiBold", size: 14)).accessibilityAddTraits(.updatesFrequently)
            }
            Text("One-time consumable purchases. No subscription. Coins do not expire and have no cash value. Chats, photos in chats, voice and video conversations are always free.")
                .font(.custom("AvenirNext-Regular", size: 12)).foregroundStyle(KokoInk.secondary)
            KokoAction(title: "See what uses coins", icon: 8, emphasis: false) { walletSection = "Ways to use" }
            KokoAction(title: purchases.recoveringOrders ? "Checking Apple orders…" : "Check unfinished purchases", emphasis: false) {
                purchases.recoverUnfinishedPurchases(showResult: true)
            }.disabled(busy)
            Text("The wallet is saved to this device. Completed coin packs are consumable and are not restored as a new balance. Keep this app's data until account syncing is available.")
                .font(.custom("AvenirNext-Regular", size: 12)).foregroundStyle(KokoInk.secondary)
        }
    }

    private var spendingGuide: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Only the little extras").font(.custom("AvenirNext-Bold", size: 25))
            KokoCard(tint: 3) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Conversation is free.").font(.custom("AvenirNext-Bold", size: 20))
                    Text("Text and image messages, voice and video conversations, entering or hosting rooms, follows, comments, likes and saved moments cost 0 coins.").font(.custom("AvenirNext-Regular", size: 14))
                }
            }
            Text("Optional room gifts").font(.custom("AvenirNext-DemiBold", size: 19))
            Text("Each gift costs the amount shown. Sending several multiplies the cost. Giving an item you already own uses that item, with no second coin charge.").font(.custom("AvenirNext-Regular", size: 13))
            ForEach(KokoCommunity.keepsakes.filter { !$0.wearable }) { item in spendingRow(item) }
            Text("Personal decorations").font(.custom("AvenirNext-DemiBold", size: 19))
            Text("Pay once to own a decoration. Wearing it, switching it or taking it off is free; no expiry or renewal.").font(.custom("AvenirNext-Regular", size: 13))
            ForEach(KokoCommunity.keepsakes.filter(\.wearable)) { item in spendingRow(item) }
            KokoAction(title: "Visit the little shop", icon: 8) { navigation.open(.shop) }
            Text("Rooms and gifting are available in this version. Gifts do not transfer money or earnings to another person.").font(.custom("AvenirNext-Regular", size: 12)).foregroundStyle(KokoInk.secondary)
        }
    }
    private func spendingRow(_ item: RoomKeepsake) -> some View {
        HStack(spacing: 12) {
            Artwork(sheet: .collection, tile: item.artworkTile).frame(width: 54, height: 54)
            Text(item.keepsakeName).font(.custom("AvenirNext-DemiBold", size: 14))
            Spacer()
            Text("\(item.tokenCost) coins").font(.custom("AvenirNext-Bold", size: 14))
        }.padding(12).background(ArtworkSurface())
    }
    private var walletHistory: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your coin story").font(.custom("AvenirNext-Bold", size: 23))
            if (community.journal?.walletHistory ?? []).isEmpty {
                Text("Your welcome gift, Apple purchases and spending will appear here.").font(.custom("AvenirNext-Regular", size: 14))
            }
            ForEach(community.journal?.walletHistory ?? []) { record in
                KokoCard {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(record.detailLine).font(.custom("AvenirNext-DemiBold", size: 14))
                            Text(record.recordedAt, format: .dateTime.month().day().hour().minute()).font(.custom("AvenirNext-Regular", size: 11)).foregroundStyle(KokoInk.secondary)
                        }
                        Spacer()
                        Text(record.tokenChange > 0 ? "+\(record.tokenChange)" : "\(record.tokenChange)").font(.custom("AvenirNext-Bold", size: 16)).monospacedDigit()
                    }
                }
            }
        }
    }
}
