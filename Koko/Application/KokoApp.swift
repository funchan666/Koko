import SwiftUI

@main
struct KokoApp: App {
    @StateObject private var community = CommunityJournalStore()
    @StateObject private var coinPurchases = KokoAppleCoinPurchases()
    @StateObject private var language = KokoLanguagePreference()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            KokoScreenCanvas { KokoApplicationRoot() }
                .environmentObject(community)
                .environmentObject(coinPurchases)
                .environmentObject(language)
                .environment(\.locale, Locale(identifier: language.selected.rawValue))
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
                .font(KokoTypography.body(size: 16, relativeTo: .body))
                .foregroundStyle(KokoInk.primary)
                .tint(KokoInk.accent)
        }
    }
}
