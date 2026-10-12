import SwiftUI

@main
struct KokoApp: App {
    @UIApplicationDelegateAdaptor(KokoApplicationDelegate.self) private var applicationDelegate
    @StateObject private var arrival = KokoArrivalCoordinator()
    @StateObject private var collection = KokoCommunityCollection.shared
    @StateObject private var community = CommunityJournalStore()
    @StateObject private var coinPurchases = KokoAppleCoinPurchases()
    @StateObject private var language = KokoLanguagePreference()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            KokoScreenCanvas { KokoApplicationRoot() }
                .environmentObject(community)
                .environmentObject(arrival)
                .environmentObject(collection)
                .environmentObject(coinPurchases)
                .environmentObject(language)
                .environment(\.locale, Locale(identifier: language.selected.rawValue))
                .task {
                    if scenePhase == .active { KokoArrivalNotifications.shared.foreground() }
                    coinPurchases.startObserving(community: community)
                    arrival.start(community: community, purchases: coinPurchases)
                    coinPurchases.recoverUnfinishedPurchases()
                }
                .onChange(of: community.myID) { _ in arrival.localAccountChanged(); coinPurchases.recoverUnfinishedPurchases() }
                .onChange(of: community.journal?.notices) { _ in arrival.noticesChanged() }
                .onReceive(collection.$snapshot) { _ in community.objectWillChange.send(); coinPurchases.recoverUnfinishedPurchases() }
                .onOpenURL { url in
                    if url.scheme == Bundle.main.bundleIdentifier { arrival.foreground(true) }
                }
                .onChange(of: scenePhase) { phase in
                    arrival.foreground(phase == .active)
                    if phase == .active {
                        KokoArrivalNotifications.shared.foreground()
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
