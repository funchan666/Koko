import SwiftUI
import AuthenticationServices

enum KokoDestination: Hashable {
    case search, room(String), createRoom(Bool), moment(String), profile(String), conversation(String), call(String, KokoConversationChannel), roomConnection(String, Int?)
    case wallet, shop, backpack, checkIn, level, settings, editProfile, album, friends(String), notices, ranking
    case feedback, blacklist, preferences(String), policy(String), savedMoments
}

@MainActor
final class KokoSceneNavigation: ObservableObject {
    @Published var selectedTab = 0
    @Published var journey: [KokoDestination] = []
    func open(_ destination: KokoDestination) { journey.append(destination) }
    func back() { if !journey.isEmpty { journey.removeLast() } }
    func goHome() { journey = []; selectedTab = 0 }
}

struct KokoApplicationRoot: View {
    @EnvironmentObject private var purchases: KokoAppleCoinPurchases
    @EnvironmentObject private var community: CommunityJournalStore
    @StateObject private var accessJourney = KokoAccessJourney()
    @State private var openingApp = true
    private var showsFeedback: Bool { community.notice != nil || purchases.purchaseMessage != nil }
    var body: some View {
        ZStack {
            Group {
                if openingApp { KokoLaunchLoading() }
                else if let journal = community.journal {
                    if !community.hasCurrentPolicyConsent { KokoConsentRenewalGate() }
                    else if journal.completedProfile && !community.requiresAppleProfileReview { KokoMainShell().id(journal.member.id) }
                    else { KokoProfileEditor(isOnboarding: true) }
                } else { KokoAccountEntry() }
            }
            .allowsHitTesting(!showsFeedback)
            .accessibilityHidden(showsFeedback)
            if accessJourney.transitioning {
                KokoAccountLoading().accessibilityHidden(showsFeedback).zIndex(90)
            }
            if let message = purchases.purchaseMessage {
                KokoNoticePanel(heading: "Purchase update", message: message,
                                dismiss: { purchases.purchaseMessage = nil })
                    .id(message)
                    .allowsHitTesting(community.notice == nil)
                    .accessibilityHidden(community.notice != nil)
                    .zIndex(99)
            }
            if let notice = community.notice {
                KokoNoticePanel(heading: "Please note", message: notice,
                                dismiss: { community.notice = nil })
                    .id(notice).zIndex(100)
            }
        }.environmentObject(accessJourney)
            .preferredColorScheme(showsFeedback || accessJourney.showsPolicyReader || (accessJourney.usesDarkWelcomeAppearance && community.journal == nil) ? .dark : .light)
            .task {
                guard openingApp else { return }
                community.refreshAppleCredentialState()
                do { try await Task.sleep(nanoseconds: 1_600_000_000) } catch { return }
                openingApp = false
            }
            .onReceive(NotificationCenter.default.publisher(for: ASAuthorizationAppleIDProvider.credentialRevokedNotification)) { _ in community.invalidateAppleSession() }
    }
}

struct KokoMainShell: View {
    @Environment(\.kokoScreenInsets) private var screenInsets
    @EnvironmentObject private var community: CommunityJournalStore
    @StateObject private var navigation = KokoSceneNavigation()
    var body: some View {
        VStack(spacing: 0) {
            if let destination = navigation.journey.last {
                destinationView(destination).id(destination)
            } else {
                Group {
                    switch navigation.selectedTab {
                    case 0: KokoDiscoverView()
                    case 1: KokoRoomDirectory()
                    case 2: KokoConversationsView()
                    default: KokoPersonalSpace()
                    }
                }.environment(\.kokoScreenInsets, EdgeInsets(top: screenInsets.top, leading: screenInsets.leading,
                                                            bottom: 0, trailing: screenInsets.trailing))
                HStack(spacing: 2) {
                    ForEach(0..<4) { index in
                        Button { navigation.selectedTab = index } label: {
                            VStack(spacing: 2) {
                                Artwork(sheet: .navigation, tile: index).frame(width: 27, height: 27)
                                Text(["Discover", "Rooms", "Messages", "My space"][index]).font(.custom(navigation.selectedTab == index ? "AvenirNext-Bold" : "AvenirNext-Medium", size: 11))
                            }.foregroundStyle(KokoInk.primary).frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(ArtworkSurface(tile: navigation.selectedTab == index ? 3 : 2))
                        }.buttonStyle(KokoPressStyle()).accessibilityAddTraits(navigation.selectedTab == index ? .isSelected : [])
                    }
                }.padding(.horizontal, 12).padding(.bottom, screenInsets.bottom + 4).background(ArtworkBackdrop())
            }
        }.background(ArtworkBackdrop())
            .overlay {
                if let request = community.coinSpendRequest { KokoCoinSpendConfirmation(request: request) }
                if community.welcomeGiftNeedsPresentation { KokoFirstRecordWelcome() }
            }
            .environmentObject(navigation)
            .task { community.welcomeOnFirstHomeVisit() }
            .onChange(of: community.coinShortfall?.id) { identifier in
                guard identifier != nil else { return }
                if navigation.journey.last != .wallet { navigation.open(.wallet) }
            }
    }
    @ViewBuilder private func destinationView(_ destination: KokoDestination) -> some View {
        switch destination {
        case .search: KokoDiscoverySearch()
        case .room(let id): KokoListeningRoomView(roomID: id)
        case .createRoom(let video): KokoRoomComposer(videoStage: video)
        case .moment(let id): KokoMomentDetail(momentID: id)
        case .profile(let id): KokoMemberProfile(memberID: id)
        case .conversation(let id): KokoConversationDetail(memberID: id)
        case .call(let id, let channel): KokoPrivateCallView(memberID: id, channel: channel)
        case .roomConnection(let id, let seat): KokoRoomConnectionView(roomID: id, preferredSeat: seat)
        case .wallet: KokoWalletView()
        case .shop: KokoKeepsakeCollection(backpack: false)
        case .backpack: KokoKeepsakeCollection(backpack: true)
        case .checkIn: KokoCheckInView()
        case .level: KokoLevelView()
        case .settings: KokoSettingsView()
        case .editProfile: KokoProfileEditor(isOnboarding: false, onFinish: navigation.back)
        case .album: KokoAlbumView()
        case .friends(let kind): KokoConnectionsView(kind: kind)
        case .notices: KokoNoticesView()
        case .ranking: KokoRankingView()
        case .feedback: KokoFeedbackView()
        case .blacklist: KokoBlacklistView()
        case .preferences(let kind): KokoPreferencesView(kind: kind)
        case .policy(let kind): KokoPolicyView(kind: kind, onBack: navigation.back)
        case .savedMoments: KokoSavedMomentsView()
        }
    }
}
