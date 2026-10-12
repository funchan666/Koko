import SwiftUI
import AuthenticationServices

enum KokoDestination: Hashable {
    case search, room(String), createRoom(Bool), moment(String), profile(String), conversation(String), call(String, KokoConversationChannel), roomConnection(String, Int?)
    case wallet, shop, backpack, checkIn, level, settings, editProfile, album, friends(String), notices, ranking
    case feedback, blacklist, preferences(String), policy(String), savedMoments, momentsCollection, language
    case conversationStarters(String?), sharedInterests, personalAnswers(String?), roomFromStarter(String)
    case conversationStudio(String?), conversationPlan(String, String?)
    case composeMoment, pendingMoments
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
    @EnvironmentObject private var arrival: KokoArrivalCoordinator
    @EnvironmentObject private var purchases: KokoAppleCoinPurchases
    @EnvironmentObject private var community: CommunityJournalStore
    @StateObject private var accessJourney = KokoAccessJourney()
    @State private var openingApp = true
    private var showsFeedback: Bool { arrival.bulletin != nil || community.notice != nil || purchases.purchaseMessage != nil || community.feedback != nil || community.safetyRequest != nil }
    private var accountIsTransitioning: Bool { accessJourney.transitioning || community.accountDeparture != nil }
    var body: some View {
        ZStack {
            KokoHostedRoomContainer(session: arrival.room)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(arrival.destination == .hostedRoom && purchases.gatewayPaymentCaption == nil && !showsFeedback)
                .accessibilityHidden(arrival.destination != .hostedRoom)
            Group {
                if openingApp || arrival.restoreRequired { KokoLaunchLoading() }
                else if arrival.destination == .roomFailure || arrival.destination == .sessionFailure { KokoRoomRecoveryPanel() }
                else if arrival.destination == .hostedRoom { Color.clear }
                else if arrival.destination == .community, let journal = community.journal {
                    if !community.hasCurrentPolicyConsent { KokoConsentRenewalGate() }
                    else if community.hasCompletedAccountEntry { KokoMainShell().id(journal.member.id) }
                    else { KokoProfileEditor(isOnboarding: true) }
                } else if community.feedback != nil { ArtworkBackdrop() }
                else { KokoAccountEntry(initialDestination: community.signedOutDestination) }
            }
            .allowsHitTesting(arrival.destination != .hostedRoom && !showsFeedback && !accountIsTransitioning)
            .accessibilityHidden(arrival.destination == .hostedRoom || showsFeedback || accountIsTransitioning)
            if let caption = purchases.gatewayPaymentCaption {
                Text(caption).font(KokoTypography.emphasis(size: 18)).multilineTextAlignment(.center)
                    .padding(32).frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(KokoWelcomePalette.backdrop.opacity(0.94))
                    .contentShape(Rectangle()).onTapGesture {}.zIndex(200)
            }
            if let bulletin = arrival.bulletin, community.notice == nil, community.feedback == nil, purchases.purchaseMessage == nil {
                KokoNoticePanel(heading: bulletin.headline, message: bulletin.explanation, dismiss: arrival.dismissBulletin)
                    .onAppear { arrival.bulletinDisplayed() }.zIndex(97)
            }
            if let departure = community.accountDeparture {
                KokoAccountLoading(captionOverride: departure.caption)
                    .zIndex(101)
            } else if accessJourney.transitioning {
                KokoAccountLoading().accessibilityHidden(showsFeedback).zIndex(90)
            }
            if community.accountDeparture == nil, let message = purchases.purchaseMessage {
                KokoNoticePanel(heading: "Purchase update", message: message,
                                dismiss: { purchases.purchaseMessage = nil })
                    .id(message)
                    .allowsHitTesting(community.notice == nil && community.feedback == nil)
                    .accessibilityHidden(community.notice != nil || community.feedback != nil)
                    .zIndex(99)
            }
            if community.accountDeparture == nil, let target = community.safetyRequest {
                KokoSafetyPanel(reportedContentID: target.contentID, memberID: target.memberID) { community.safetyRequest = nil }
                    .allowsHitTesting(community.notice == nil && community.feedback == nil && purchases.purchaseMessage == nil)
                    .accessibilityHidden(community.notice != nil || community.feedback != nil || purchases.purchaseMessage != nil)
                    .zIndex(98)
            }
            if community.accountDeparture == nil, let feedback = community.feedback {
                KokoActionFeedbackPanel(feedback: feedback) { community.feedback = nil }
                    .allowsHitTesting(community.notice == nil)
                    .accessibilityHidden(community.notice != nil)
                    .zIndex(100)
            }
            if community.accountDeparture == nil, let notice = community.notice {
                KokoNoticePanel(heading: "Please note", message: notice,
                                dismiss: { community.notice = nil })
                    .id(notice).zIndex(100)
            }
        }.environmentObject(accessJourney)
            .preferredColorScheme(.dark)
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
    @EnvironmentObject private var collection: KokoCommunityCollection
    @Environment(\.kokoScreenInsets) private var screenInsets
    @EnvironmentObject private var community: CommunityJournalStore
    @StateObject private var navigation = KokoSceneNavigation()
    var body: some View {
        GeometryReader { viewport in
            VStack(spacing: 0) {
            if let error = collection.error {
                VStack(spacing: 4) {
                    Text(error).font(KokoTypography.body(size: 13))
                    KokoWelcomeAction(title: "Reload community", primary: false) { Task { await collection.load() } }
                }.padding(.horizontal, 20).padding(.top, screenInsets.top)
            }
            if let destination = navigation.journey.last {
                destinationView(destination)
                    .id(destination)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .clipped()
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
                .frame(maxWidth: .infinity, alignment: .top)
                .clipped()
                HStack(spacing: 6) {
                    ForEach(0..<4) { index in
                        Button { navigation.selectedTab = index } label: {
                            KokoTabIcon(index: index, selected: navigation.selectedTab == index)
                                .frame(maxWidth: .infinity, minHeight: 58)
                                .contentShape(Rectangle())
                                .background { if navigation.selectedTab == index { KokoTabSelectionSurface() } }
                        }
                        .buttonStyle(KokoPressStyle())
                        .accessibilityLabel(Text(LocalizedStringKey(["Discover live rooms", "Browse voice rooms", "Open messages", "Open my space"][index])))
                        .accessibilityAddTraits(navigation.selectedTab == index ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, screenInsets.bottom + 6)
                .background {
                    Color(red: 7 / 255, green: 28 / 255, blue: 30 / 255)
                        .accessibilityHidden(true)
                }
            }
        }
            .frame(width: viewport.size.width, height: viewport.size.height, alignment: .top)
            .clipped()
            .background(ArtworkBackdrop())
            .overlay {
                if let request = community.coinSpendRequest {
                    KokoCoinSpendConfirmation(request: request)
                }
            }
            .environmentObject(navigation)
            .task { community.welcomeOnFirstHomeVisit() }
            .onChange(of: community.coinShortfall?.id) { identifier in
                guard identifier != nil else { return }
                if navigation.journey.last != .wallet { navigation.open(.wallet) }
            }
        }
        .ignoresSafeArea(.container, edges: .all)
    }
    @ViewBuilder private func destinationView(_ destination: KokoDestination) -> some View {
        switch destination {
        case .conversationStudio(let roomID): KokoConversationStudio(roomID: roomID)
        case .conversationPlan(let id, let roomID): KokoConversationPlanView(planID: id, suggestedRoomID: roomID)
        case .composeMoment: KokoMomentComposer()
        case .pendingMoments: KokoPendingMomentsView()
        case .search: KokoDiscoverySearch()
        case .momentsCollection: KokoMomentsCollection()
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
        case .language: KokoLanguageSettingsView()
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
        case .conversationStarters(let recipientID): KokoConversationStartersView(recipientID: recipientID)
        case .sharedInterests: KokoSharedInterestsView()
        case .personalAnswers(let starterID): KokoPersonalAnswersView(initialStarterID: starterID)
        case .roomFromStarter(let starterID): KokoRoomComposer(videoStage: false, starter: ConversationStarter.find(starterID))
        }
    }
}
