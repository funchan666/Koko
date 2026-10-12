import Foundation
import StoreKit

@MainActor
final class KokoPurchaseReceiptRefresh: NSObject, SKRequestDelegate {
    private var request: SKReceiptRefreshRequest?
    private var waiter: CheckedContinuation<Void, Never>?
    private var timeout: Task<Void, Never>?
    func refreshForForegroundPurchase() async {
        guard request == nil else { return }
        await withCheckedContinuation { continuation in
            waiter = continuation
            let request = SKReceiptRefreshRequest(); self.request = request
            request.delegate = self; request.start()
            timeout = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
                self?.finish()
            }
        }
    }
    nonisolated func requestDidFinish(_ request: SKRequest) {
        Task { @MainActor [weak self] in self?.finish() }
    }
    nonisolated func request(_ request: SKRequest, didFailWithError error: Error) {
        Task { @MainActor [weak self] in self?.finish() }
    }
    private func finish() {
        timeout?.cancel(); timeout = nil
        request?.delegate = nil; request?.cancel(); request = nil
        let continuation = waiter; waiter = nil; continuation?.resume()
    }
}
