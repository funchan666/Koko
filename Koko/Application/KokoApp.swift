import SwiftUI

@main
struct KokoApp: App {
    @StateObject private var community = CommunityJournalStore()
    @StateObject private var coinPurchases = KokoAppleCoinPurchases()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            KokoScreenCanvas { KokoApplicationRoot() }
                .environmentObject(community)
                .environmentObject(coinPurchases)
                .task {
                    coinPurchases.startObserving(community: community)
                    coinPurchases.recoverUnfinishedPurchases()
                }
                .onChange(of: community.myID) { _ in coinPurchases.recoverUnfinishedPurchases() }
                .onChange(of: scenePhase) { phase in
                    if phase == .active {
                        coinPurchases.recoverUnfinishedPurchases()
                        community.refreshAppleCredentialState()
                    }
                }
                .font(.custom("AvenirNext-Regular", size: 16, relativeTo: .body))
                .foregroundStyle(KokoInk.primary)
                .tint(KokoInk.accent)
        }
    }
}
