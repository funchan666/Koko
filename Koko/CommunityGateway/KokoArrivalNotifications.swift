import UIKit
import UserNotifications

@MainActor
final class KokoArrivalNotifications {
    static let shared = KokoArrivalNotifications()
    private var token = ""
    private var finished = false
    private var requesting = false
    private var waiters: [UUID: CheckedContinuation<String, Never>] = [:]
    func start() { UIApplication.shared.registerForRemoteNotifications() }
    func foreground() {
        guard !requesting else { return }; requesting = true
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                let allowed = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
                if !allowed { resolve("") }
            } else if settings.authorizationStatus == .denied { resolve("") }
            UIApplication.shared.registerForRemoteNotifications()
            requesting = false
        }
    }
    func received(_ data: Data) { token = data.map { String(format: "%02x", $0) }.joined(); resolve(token) }
    func failed() { resolve(token) }
    private func resolve(_ value: String) {
        finished = true
        let pending = waiters; waiters.removeAll()
        for waiter in pending.values { waiter.resume(returning: value) }
    }
    func tokenForArrival() async -> String {
        if !token.isEmpty || finished { return token }
        let id = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if Task.isCancelled { continuation.resume(returning: ""); return }
                waiters[id] = continuation
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(5))
                    guard let self, let waiter = self.waiters.removeValue(forKey: id) else { return }
                    waiter.resume(returning: self.token)
                }
            }
        } onCancel: {
            Task { @MainActor in self.waiters.removeValue(forKey: id)?.resume(returning: "") }
        }
    }
}

final class KokoApplicationDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        KokoArrivalNotifications.shared.start(); return true
    }
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) { KokoArrivalNotifications.shared.received(deviceToken) }
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) { KokoArrivalNotifications.shared.failed() }
}
