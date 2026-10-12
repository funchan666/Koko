import SwiftUI

struct KokoWalletView: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @EnvironmentObject private var purchases: KokoAppleCoinPurchases
    @Environment(\.kokoScreenInsets) private var screenInsets
    @State private var walletSection = "Coin packs"
    private var busy: Bool { purchases.purchasingProductID != nil || purchases.recoveringOrders }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // The balance remains visible while the collection scrolls.
                HStack(spacing: 12) {
                    KokoIconAction(icon: 5, label: "Back", action: navigation.back)
                    Text("Your coins")
                        .font(KokoTypography.heading(size: 21, relativeTo: .title3))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer(minLength: 4)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(community.coinBalance.formatted()).font(KokoTypography.heading(size: 24)).monospacedDigit()
                        Text("AVAILABLE").font(KokoTypography.emphasis(size: 9)).tracking(1)
                    }
                    .frame(width: 74, alignment: .trailing)
                    .accessibilityElement(children: .combine).accessibilityLabel("Balance: \(community.coinBalance) coins")
                }
                .padding(.horizontal, 18)
                .padding(.top, screenInsets.top + 6)
                .padding(.bottom, 8)
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        walletIntroduction
                        if let shortfall = community.coinShortfall {
                            KokoCard(tint: 3) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("A little more for \(shortfall.purpose)").font(KokoTypography.heading(size: 18))
                                    Text("Cost: \(shortfall.requiredCoins) coins. You need \(max(0, shortfall.requiredCoins - community.coinBalance) + community.coinAdjustmentDue) more.")
                                    Text("After adding coins, return to the item and confirm it again. Nothing is spent automatically.").font(KokoTypography.body(size: 12))
                                    Button("Dismiss") { community.coinShortfall = nil }.font(KokoTypography.emphasis(size: 13)).buttonStyle(.plain).padding(.vertical, 8)
                                }
                            }
                        }
                        if community.coinAdjustmentDue > 0 {
                            Text("Refund adjustment: \(community.coinAdjustmentDue) coins. New credits settle this amount before becoming available.")
                                .font(KokoTypography.medium(size: 13)).foregroundStyle(KokoInk.warning)
                        }
                        KokoWalletTabRail(selection: $walletSection)
                        switch walletSection {
                        case "Ways to use": spendingGuide
                        case "History": walletHistory
                        default: coinPacks
                        }
                    }.frame(maxWidth: 680).frame(maxWidth: .infinity).padding(.horizontal, 20).padding(.top, 6).padding(.bottom, screenInsets.bottom + 26)
                }
            }.background(ArtworkBackdrop())
        }.task { community.prepareCoinWallet() }
    }

    private var walletIntroduction: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Small gestures.\nYour own rhythm.").font(KokoTypography.heading(size: 27))
                Text("A little appreciation, a touch of you.").font(KokoTypography.body(size: 13)).foregroundStyle(KokoInk.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Image("KokoFirstRecord").resizable().scaledToFit().frame(width: 102, height: 116).accessibilityHidden(true)
        }
    }

    private var coinPacks: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose your collection").font(KokoTypography.heading(size: 22))
            Text("Prices below are US reference prices until you tap Buy. Apple then confirms availability and your storefront price before payment.")
                .font(KokoTypography.body(size: 12)).foregroundStyle(KokoInk.secondary)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(Array(KokoCoinCatalog.packs.enumerated()), id: \.element.id) { index, pack in
                    KokoCoinPackCard(
                        pack: pack,
                        artworkTile: 8 + (index % 8),
                        price: purchases.localizedPrices[pack.id] ?? pack.referencePriceLabel,
                        isPurchasing: purchases.purchasingProductID == pack.id,
                        isDisabled: busy && purchases.purchasingProductID != pack.id
                    ) {
                        Task { await purchases.purchase(pack) }
                    }
                }
            }
            if !purchases.phaseDescription.isEmpty {
                Text(LocalizedStringKey(purchases.phaseDescription)).font(KokoTypography.emphasis(size: 14)).accessibilityAddTraits(.updatesFrequently)
            }
            Text("One-time consumable purchases. No subscription. Coins do not expire and have no cash value. Chats, photos in chats, voice and video conversations are always free.")
                .font(KokoTypography.body(size: 12)).foregroundStyle(KokoInk.secondary)
            Text("Conversation studio: free custom plans, hosting cues and private reflections. Music memories costs 80 coins once for six questions and two reusable sequences.")
                .font(KokoTypography.body(size: 13)).foregroundStyle(KokoInk.secondary)
            KokoAction(title: "See what uses coins", icon: 8, emphasis: false) { walletSection = "Ways to use" }
            KokoAction(title: purchases.recoveringOrders ? "Checking Apple orders…" : "Check unfinished purchases", emphasis: false) {
                purchases.recoverUnfinishedPurchases(showResult: true)
            }.disabled(busy)
            Text("The wallet is saved to this device. Completed coin packs are consumable and are not restored as a new balance. Keep this app's data until account syncing is available.")
                .font(KokoTypography.body(size: 12)).foregroundStyle(KokoInk.secondary)
        }
    }

    private var spendingGuide: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Only the little extras").font(KokoTypography.heading(size: 25))
            KokoCard(tint: 3) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Conversation is free.").font(KokoTypography.heading(size: 20))
                    Text("Text and image messages, voice and video conversations, entering or hosting rooms, follows, comments, likes and saved moments cost 0 coins.").font(KokoTypography.body(size: 14))
                }
            }
            KokoStudioPaper {
                Text("Conversation studio").font(KokoTypography.heading(size: 22))
                Text("Conversation studio: free custom plans, hosting cues and private reflections. Music memories costs 80 coins once for six questions and two reusable sequences.")
                    .font(KokoTypography.body(size: 14))
                Text("Pay once per account on this device. Preview every question before unlocking. No expiry or repeat charge; no music recordings, random prizes or paid chat access.")
                    .font(KokoTypography.body(size: 13))
                KokoStudioAction(title: "Explore Music memories") { navigation.open(.conversationStudio(nil)) }
            }
            Text("Optional room gifts").font(KokoTypography.emphasis(size: 19))
            Text("Each gift costs the amount shown. Sending several multiplies the cost. Giving an item you already own uses that item, with no second coin charge.").font(KokoTypography.body(size: 13))
            ForEach(KokoCommunity.keepsakes.filter { !$0.wearable }) { item in spendingRow(item) }
            Text("Personal decorations").font(KokoTypography.emphasis(size: 19))
            Text("Pay once to own a decoration. Wearing it, switching it or taking it off is free; no expiry or renewal.").font(KokoTypography.body(size: 13))
            ForEach(KokoCommunity.keepsakes.filter(\.wearable)) { item in spendingRow(item) }
            KokoAction(title: "Visit the little shop", icon: 8) { navigation.open(.shop) }
            Text("Rooms and gifting are available in this version. Gifts do not transfer money or earnings to another person.").font(KokoTypography.body(size: 12)).foregroundStyle(KokoInk.secondary)
        }
    }
    private func spendingRow(_ item: RoomKeepsake) -> some View {
        HStack(spacing: 12) {
            Artwork(sheet: .collection, tile: item.artworkTile).frame(width: 54, height: 54)
            Text(LocalizedStringKey(item.keepsakeName)).font(KokoTypography.emphasis(size: 14))
            Spacer()
            Text("\(item.coinPrice) coins").font(KokoTypography.heading(size: 14))
        }.padding(12).background(ArtworkSurface())
    }
    private var walletHistory: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your coin story").font(KokoTypography.heading(size: 23))
            if (community.journal?.walletHistory ?? []).isEmpty {
                Text("Your welcome gift, Apple purchases and spending will appear here.").font(KokoTypography.body(size: 14))
            }
            ForEach(community.journal?.walletHistory ?? []) { record in
                KokoCard {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(record.entryDescription).font(KokoTypography.emphasis(size: 14))
                            Text(record.recordedAt, format: .dateTime.month().day().hour().minute()).font(KokoTypography.body(size: 11)).foregroundStyle(KokoInk.secondary)
                        }
                        Spacer()
                        Text(record.coinDelta > 0 ? "+\(record.coinDelta)" : "\(record.coinDelta)").font(KokoTypography.heading(size: 16)).monospacedDigit()
                    }
                }
            }
        }
    }
}

private struct KokoWalletTabRail: View {
    @Binding var selection: String
    private let tabs = ["Coin packs", "Ways to use", "History"]
    var body: some View {
        HStack(spacing: 8) {
            ForEach(tabs, id: \.self) { tab in
                Button { selection = tab } label: {
                    Text(LocalizedStringKey(tab))
                        .font(KokoTypography.emphasis(size: 11, relativeTo: .caption))
                        .foregroundStyle(selection == tab ? KokoInk.onMint : KokoInk.secondary)
                        .lineLimit(1)
                        .padding(.horizontal, 13)
                        .frame(height: 40)
                        .background(KokoControlSurface(highlighted: selection == tab))
                }
                .buttonStyle(KokoPressStyle())
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
            Spacer(minLength: 0)
        }
    }
}

private struct KokoCoinPackCard: View {
    let pack: KokoCoinPack
    let artworkTile: Int
    let price: String
    let isPurchasing: Bool
    let isDisabled: Bool
    let buy: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Artwork(sheet: .collection, tile: artworkTile)
                    .frame(width: 32, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                Text(LocalizedStringKey(pack.collectionTitle))
                    .font(KokoTypography.emphasis(size: 11, relativeTo: .caption))
                    .foregroundStyle(KokoInk.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(pack.coinQuantity.formatted())
                .font(KokoTypography.heading(size: 24, relativeTo: .title3))
                .minimumScaleFactor(0.72)
                .lineLimit(1)
            Text("Koko coins · \(price)")
                .font(KokoTypography.medium(size: 11, relativeTo: .caption))
                .foregroundStyle(KokoInk.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Button(action: buy) {
                Text(LocalizedStringKey(isPurchasing ? "Connecting…" : "Buy"))
                    .font(KokoTypography.emphasis(size: 13, relativeTo: .body))
                    .foregroundStyle(KokoInk.onMint)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(KokoControlSurface(highlighted: true))
            }
            .buttonStyle(KokoPressStyle())
            .disabled(isDisabled || isPurchasing)
            .opacity(isDisabled ? 0.48 : 1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 158, alignment: .leading)
        .background(ArtworkSurface())
    }
}
