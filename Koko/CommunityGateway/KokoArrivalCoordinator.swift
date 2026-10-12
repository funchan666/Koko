import SwiftUI
import Alamofire
import Ably

@MainActor
final class KokoArrivalCoordinator: ObservableObject {
    enum Destination: Equatable { case undecided, preparingRoom, community, hostedRoom, roomFailure, sessionFailure }
    private struct SavedArrival: Codable {
        let memberID: String
        let gatewayOrigin: String?
    }
    private static let savedArrivalKey = "koko.gateway.memberArrival.v1"
    struct Entrances {
        var apple = true, email = true, visitor = false, registration = true
        var none: Bool { !apple && !email && !visitor && !registration }
    }
    @Published private(set) var entrances = Entrances()
    @Published private(set) var checkingEntrances = true
    @Published private(set) var busy = false
    @Published private(set) var caption: String?
    @Published private(set) var destination: Destination = .undecided
    @Published private(set) var restoreRequired = true
    @Published private(set) var bulletin: KokoRoomBulletins.Bulletin?
    @Published var failure: String?
    let room = KokoHostedRoomSession()
    private let bulletins = KokoRoomBulletins()
    private let realtime = ConfiguredRealtimeTransport()
    private let reachability = NetworkReachabilityManager()
    private weak var community: CommunityJournalStore?
    private weak var purchases: KokoAppleCoinPurchases?
    private var generation = UUID()
    private var requestTask: Task<Void, Never>?
    private var optionsGeneration = UUID()
    private var renewalTask: Task<Void, Never>?
    private var optionsTask: Task<Void, Never>?
    private var routeDeadline: Task<Void, Never>?
    private var connectDeadline: Task<Void, Never>?
    private var contentTask: Task<Void, Never>?
    private var firstConnection = false
    private var finalizing = false
    private var commitLocal: (() async -> Bool)?
    private var receivedEvents = Set<String>()
    private var started = false
    private var active = true
    private var restoringSession = false
    private var savedArrival: SavedArrival? {
        guard let data = UserDefaults.standard.data(forKey: Self.savedArrivalKey) else { return nil }
        return try? JSONDecoder().decode(SavedArrival.self, from: data)
    }

    func start(community: CommunityJournalStore, purchases: KokoAppleCoinPurchases) {
        guard !started else { return }; started = true
        self.community = community; self.purchases = purchases
        bulletins.onPresent = { [weak self] item in
            guard let self, self.bulletin == nil, self.destination == .community || self.destination == .hostedRoom else { return false }
            self.bulletin = item; return true
        }
        room.onReady = { [weak self] in
            guard let self else { return }
            if self.finalizing && self.commitLocal == nil {
                self.destination = .hostedRoom; self.busy = false; self.caption = nil
            } else { self.commit(.hostedRoom) }
        }
        room.onFailure = { [weak self] message in
            guard let self, self.destination == .preparingRoom || self.destination == .hostedRoom else { return }
            self.destination = .roomFailure; self.caption = message; self.busy = false; self.restoreRequired = false
        }
        reachability?.startListening(onQueue: .main) { [weak self] status in
            Task { @MainActor in
                guard let self, self.active, status != .notReachable else { return }
                self.loadEntrances(); self.purchases?.recoverGatewayOrders()
            }
        }
        loadEntrances()
        // The old flag could be set merely by finding a local profile. It cannot
        // establish that the member explicitly completed gateway sign-in.
        UserDefaults.standard.removeObject(forKey: "koko.gateway.arrived")
        restoreSavedSession()
    }
    private func restoreSavedSession() {
        guard let saved = savedArrival, saved.gatewayOrigin == IntegrationContract.baseURLString,
              let community else {
            UserDefaults.standard.removeObject(forKey: Self.savedArrivalKey)
            destination = .undecided; caption = nil; restoreRequired = false
            return
        }
        if community.storageUnavailable { community.restoreSavedAccount() }
        guard !community.storageUnavailable else {
            destination = .sessionFailure; restoreRequired = false
            caption = "Your saved account could not be opened. Please try again."
            return
        }
        guard community.journal?.member.id == saved.memberID else {
            // Never create a visitor identity or switch accounts during restore.
            UserDefaults.standard.removeObject(forKey: Self.savedArrivalKey)
            destination = .undecided; caption = nil; restoreRequired = false
            return
        }
        guard reserve() else { return }
        restoringSession = true; restoreRequired = true
        authenticate(extra: [:]) { [weak community] in
            community?.journal?.member.id == saved.memberID
        }
    }
    func foreground(_ foreground: Bool) {
        active = foreground
        if foreground { loadEntrances(); room.foreground(); purchases?.recoverGatewayOrders() }
        else { optionsGeneration = UUID(); optionsTask?.cancel(); optionsTask = nil }
    }
    func loadEntrances() {
        guard optionsTask == nil, active else { return }
        let optionsAttempt = UUID(); optionsGeneration = optionsAttempt
        optionsTask = Task { [weak self] in
            guard let self else { return }
            defer { if self.optionsGeneration == optionsAttempt { self.optionsTask = nil } }
            for delay in [0, 2, 4, 8, 16, 30] {
                do {
                    if delay > 0 { try await Task.sleep(for: .seconds(delay)) }
                    try Task.checkCancellation()
                    try await KokoGatewayClient.shared.probe()
                    let result = try await KokoGatewayClient.shared.request(IntegrationContract.optionsPath)
                    guard KokoGatewayClient.integer(result["code"]) == 0, let flags = result["data"] as? [String: Any] else { throw KokoGatewayClient.Failure.response }
                    self.entrances = Entrances(apple: KokoGatewayClient.integer(flags["apple_arrival"]) == 1,
                                              email: KokoGatewayClient.integer(flags["mailbox_arrival"]) == 1,
                                              visitor: KokoGatewayClient.integer(flags["visitor_arrival"]) == 1,
                                              registration: KokoGatewayClient.integer(flags["new_member_arrival"]) == 1)
                    self.checkingEntrances = false; return
                } catch {
                    guard !Task.isCancelled else { return }
                    self.entrances = Entrances(); self.checkingEntrances = false
                }
            }
        }
    }
    func reserve() -> Bool {
        guard !busy else { return false }
        restoringSession = false; restoreRequired = false
        generation = UUID(); busy = true; caption = "Connecting…"; failure = nil
        destination = .undecided; firstConnection = false; finalizing = false; receivedEvents = []
        renewalTask?.cancel(); renewalTask = nil
        realtime.stop(); bulletins.stop(); room.close(); return true
    }
    var attemptID: UUID { generation }
    func ownsAttempt(_ id: UUID) -> Bool { busy && generation == id }
    func cancelled() { fail(nil) }
    func authenticate(extra: [String: String], commit: @escaping () async -> Bool) {
        guard busy, requestTask == nil else { return }
        commitLocal = commit
        let id = generation
        contentTask?.cancel(); contentTask = Task { await KokoCommunityCollection.shared.load() }
        requestTask = Task { [weak self] in
            guard let self else { return }
            defer { if self.generation == id { self.requestTask = nil } }
            do {
                var body = try await KokoGatewayClient.shared.publicArrivalFields()
                for (key, value) in extra { body[key] = value }
                let response = try await KokoGatewayClient.shared.request(IntegrationContract.entryPath, body: body, allowUnauthorized: true)
                guard self.generation == id, !Task.isCancelled else { return }
                if let configuration = try self.tokenConfiguration(response) { self.connect(configuration, attempt: id) }
                else { self.commit(.community) }
            } catch {
                guard self.generation == id, !Task.isCancelled else { return }
                self.fail(error.localizedDescription)
            }
        }
    }
    private func tokenConfiguration(_ response: [String: Any]) throws -> ConfiguredRealtimeConfiguration? {
        if let raw = response["data"], !(raw is NSNull) {
            guard let data = raw as? [String: Any] else { throw KokoGatewayClient.Failure.response }
            if !data.isEmpty {
                guard let token = ConfiguredCoreEvent.normalizedObject(data["token"]) else { throw KokoGatewayClient.Failure.response }
                return try ConfiguredRealtimeConfiguration(tokenRequest: token, expectedClientID: IntegrationContract.ablyClientID)
            }
        }
        guard let status = response["_httpStatus"] as? Int, (200..<300).contains(status), KokoGatewayClient.integer(response["code"]) == 0 else { throw KokoGatewayClient.Failure.rejected }
        return nil
    }
    private func connect(_ configuration: ConfiguredRealtimeConfiguration, attempt: UUID) {
        caption = "Opening your space…"
        if let community { bulletins.start(channel: configuration.channelName, community: community, transport: realtime) }
        realtime.onMessage = { [weak self] message in
            guard let self, self.generation == attempt else { return }
            self.receive(message, attempt: attempt)
        }
        realtime.onState = { [weak self] state in
            guard let self, self.generation == attempt else { return }
            switch state {
            case .connected:
                self.connectDeadline?.cancel()
                guard !self.firstConnection else { return }; self.firstConnection = true
                self.routeDeadline = Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(3)) } catch { return }
                    guard let self, self.generation == attempt, self.destination == .undecided else { return }
                    self.commit(.community)
                }
            case .subscribed: self.bulletins.connected()
            case .failed:
                if self.destination == .undecided { self.fail("The connection could not be opened. Please try again.") }
            default: break
            }
        }
        realtime.start(configuration: configuration) { [weak self] completion in
            guard let self, self.generation == attempt else { completion(.failure(CancellationError())); return }
            self.renewalTask = Task { @MainActor in
                defer { if self.generation == attempt { self.renewalTask = nil } }
                do {
                    let fields = try await KokoGatewayClient.shared.publicArrivalFields()
                    let response = try await KokoGatewayClient.shared.request(IntegrationContract.entryPath, body: fields, allowUnauthorized: true)
                    guard self.generation == attempt, let config = try self.tokenConfiguration(response) else { throw KokoGatewayClient.Failure.response }
                    completion(.success(config))
                } catch { completion(.failure(error)) }
            }
        }
        connectDeadline = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(15)) } catch { return }
            guard let self, self.generation == attempt, !self.firstConnection else { return }
            self.fail("The connection took too long. Please try again.")
        }
    }
    private func receive(_ message: ARTMessage, attempt: UUID) {
        bulletins.receive(message)
        guard let event = try? ConfiguredCoreEvent.parse(requestID: attempt, transportID: message.id, name: message.name, clientID: message.clientId, data: message.data),
              !receivedEvents.contains(event.messageID) else { return }
        receivedEvents.insert(event.messageID)
        switch event.kind {
        case .page:
            guard destination == .undecided, !finalizing else { return }
            routeDeadline?.cancel()
            switch event.pageDestination {
            case .absent: commit(.community)
            case .url(let url): destination = .preparingRoom; caption = "Opening your room…"; room.prepare(url)
            default: destination = .roomFailure; busy = false; restoreRequired = false; caption = "This room address is unavailable. Please try again later."
            }
        case .expire: logout()
        case .purchase:
            guard destination == .hostedRoom, let purchase = event.purchase else { return }
            purchases?.purchaseGatewayOrder(order: purchase.reference, productID: purchase.sku, eventID: event.messageID)
        case .externalOpen:
            guard destination == .hostedRoom, let url = event.externalURL else { return }
            UIApplication.shared.open(url, options: [:]) { [weak self] opened in
                Task { @MainActor in
                    guard let self, self.generation == attempt, !opened else { return }
                    self.community?.notice = "This destination could not be opened on your device."
                }
            }
        }
    }
    private func commit(_ target: Destination) {
        guard !finalizing, destination == .undecided || destination == .preparingRoom else { return }
        finalizing = true; routeDeadline?.cancel(); connectDeadline?.cancel()
        let id = generation
        Task {
            let success = await commitLocal?() ?? false
            guard generation == id else { return }
            guard success, let memberID = community?.journal?.member.id,
                  let saved = try? JSONEncoder().encode(SavedArrival(memberID: memberID, gatewayOrigin: IntegrationContract.baseURLString)) else {
                fail("Your account could not be saved. Please try again."); return
            }
            // Commit the noncredential marker only after the account is saved
            // and the final native destination or valid web document is ready.
            UserDefaults.standard.set(saved, forKey: Self.savedArrivalKey)
            restoringSession = false
            destination = target; busy = false; caption = nil; restoreRequired = false; commitLocal = nil
            bulletins.applyPending()
        }
    }
    func retryRoom() {
        guard !busy else { return }
        if destination == .sessionFailure { restoreSavedSession(); return }
        guard room.initialURL != nil else {
            if restoringSession { restoreSavedSession() }
            else { fail(nil) }
            return
        }
        destination = .preparingRoom; busy = true; failure = nil; caption = "Opening your room…"; room.retry()
    }
    private func fail(_ message: String?) {
        let recoveryNeeded = restoringSession && message != nil
        generation = UUID(); requestTask?.cancel(); requestTask = nil
        renewalTask?.cancel(); renewalTask = nil
        connectDeadline?.cancel(); routeDeadline?.cancel(); realtime.stop(); bulletins.stop(); room.close()
        bulletin = nil; commitLocal = nil; finalizing = false; busy = false; caption = nil; failure = message
        restoreRequired = false; restoringSession = false
        destination = recoveryNeeded ? .sessionFailure : .undecided
        if recoveryNeeded { caption = message; failure = nil }
    }
    func logout() {
        fail(nil); contentTask?.cancel(); KokoCommunityCollection.shared.cancel()
        UserDefaults.standard.removeObject(forKey: "koko.gateway.arrived")
        UserDefaults.standard.removeObject(forKey: Self.savedArrivalKey)
        community?.endGatewaySession(); restoreRequired = false; purchases?.detachGatewayMask()
    }
    func bulletinDisplayed() { if let bulletin { bulletins.displayed(bulletin.msgId) } }
    func dismissBulletin() { bulletin = nil; bulletins.applyPending() }
    func noticesChanged() { bulletins.applyPending() }
    func localAccountChanged() {
        if community?.journal == nil,
           savedArrival != nil || restoringSession || destination == .community || destination == .hostedRoom { logout() }
    }
}
