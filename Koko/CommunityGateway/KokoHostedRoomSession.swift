import SwiftUI
import WebKit
import AVFoundation

@MainActor
final class KokoHostedRoomSession: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    @Published private(set) var webView: WKWebView?
    private(set) var initialURL: URL?
    var onReady: (() -> Void)?
    var onFailure: ((String) -> Void)?
    private var navigation: WKNavigation?
    private var successfulResponse = false
    private var completedNavigation: WKNavigation?
    private var mounted = false
    private var failed = false
    private var generation = UUID()
    private var navigationGeneration = UUID()
    private var timeout: Task<Void, Never>?
    private var permittedOrigins = Set<String>()
    private var permissionTasks: [AVMediaType: Task<Bool, Never>] = [:]
    private var stagedFinish = false

    func prepare(_ url: URL) {
        close(); initialURL = url; permittedOrigins = [Self.origin(url)]
        let configuration = WKWebViewConfiguration()
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = self; view.uiDelegate = self
        view.allowsBackForwardNavigationGestures = true
        view.isOpaque = false; view.backgroundColor = .clear
        view.scrollView.contentInsetAdjustmentBehavior = .never
        webView = view
        beginNavigation()
        navigation = view.load(URLRequest(url: url))
    }
    func mountedContainer() { mounted = true; finishIfReady() }
    func retry() { guard let url = initialURL else { return }; prepare(url) }
    func foreground() { finishIfReady() }
    func close() {
        generation = UUID(); navigationGeneration = UUID(); timeout?.cancel(); timeout = nil
        for task in permissionTasks.values { task.cancel() }; permissionTasks.removeAll()
        webView?.stopLoading(); webView?.navigationDelegate = nil; webView?.uiDelegate = nil
        webView?.removeFromSuperview(); webView = nil; initialURL = nil; navigation = nil
        successfulResponse = false; completedNavigation = nil; mounted = false; stagedFinish = false; failed = false
    }
    private func beginNavigation() {
        navigationGeneration = UUID(); successfulResponse = false; completedNavigation = nil; stagedFinish = false; failed = false
        let attempt = generation, page = navigationGeneration
        timeout?.cancel()
        timeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(30)) } catch { return }
            guard let self, self.generation == attempt, self.navigationGeneration == page else { return }
            self.fail("This room could not finish loading. Please try again.")
        }
    }
    private func fail(_ message: String) {
        guard !failed else { return }; failed = true; timeout?.cancel(); stagedFinish = false
        onFailure?(message)
    }
    private func finishIfReady() {
        guard !failed, mounted, successfulResponse, let navigation, completedNavigation === navigation,
              UIApplication.shared.applicationState == .active else { return }
        timeout?.cancel()
        guard !stagedFinish else { return }; stagedFinish = true; onReady?()
    }
    static func origin(_ url: URL) -> String {
        guard let scheme = url.scheme?.lowercased(), let host = url.host?.lowercased() else { return "" }
        return scheme + "://" + host + ":" + String(url.port ?? (scheme == "https" ? 443 : 80))
    }
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        guard webView === self.webView else { return }
        if self.navigation !== navigation { beginNavigation(); self.navigation = navigation }
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard webView === self.webView, let url = navigationAction.request.url,
              ["https", "http"].contains(url.scheme?.lowercased() ?? ""), url.host != nil,
              url.user == nil, url.password == nil else { decisionHandler(.cancel); return }
        if navigationAction.targetFrame?.isMainFrame == true { permittedOrigins.insert(Self.origin(url)) }
        decisionHandler(.allow)
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        guard webView === self.webView else { decisionHandler(.cancel); return }
        if navigationResponse.isForMainFrame {
            guard let response = navigationResponse.response as? HTTPURLResponse,
                  (200..<300).contains(response.statusCode),
                  ["text/html", "application/xhtml+xml"].contains(response.mimeType?.lowercased() ?? "") else {
                decisionHandler(.cancel); fail("This room returned an unavailable page. Please try again."); return
            }
            successfulResponse = true
            if let url = response.url { permittedOrigins.insert(Self.origin(url)) }
        }
        decisionHandler(.allow)
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard webView === self.webView, self.navigation === navigation else { return }
        completedNavigation = navigation
        if successfulResponse { timeout?.cancel() }
        finishIfReady()
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard webView === self.webView, self.navigation === navigation else { return }; fail("This room could not be opened. Please try again.")
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard webView === self.webView, self.navigation === navigation else { return }
        if (error as NSError).code != NSURLErrorCancelled { fail("This room could not be reached. Please try again.") }
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard webView === self.webView else { return }; fail("The room needs to reload. Please try again.")
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard webView === self.webView, navigationAction.targetFrame == nil, let url = navigationAction.request.url,
              ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        beginNavigation(); navigation = webView.load(navigationAction.request); return nil
    }
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        let originPort = origin.port == 0 ? (origin.protocol == "https" ? 443 : 80) : origin.port
        let key = origin.protocol.lowercased() + "://" + origin.host.lowercased() + ":" + String(originPort)
        guard webView === self.webView, frame.isMainFrame, let currentURL = webView.url,
              Self.origin(currentURL) == key, permittedOrigins.contains(key), successfulResponse else { decisionHandler(.deny); return }
        let attempt = generation, page = navigationGeneration
        Task { @MainActor in
            let camera = type == .microphone ? true : await permission(.video)
            guard camera, generation == attempt, navigationGeneration == page else { decisionHandler(.deny); return }
            let microphone = type == .camera ? true : await permission(.audio)
            guard generation == attempt, navigationGeneration == page, webView === self.webView else { decisionHandler(.deny); return }
            decisionHandler(camera && microphone ? .grant : .deny)
        }
    }
    private func permission(_ type: AVMediaType) async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: type) {
        case .authorized: return true
        case .notDetermined:
            if let task = permissionTasks[type] { return await task.value }
            let task = Task { await AVCaptureDevice.requestAccess(for: type) }
            permissionTasks[type] = task
            let allowed = await task.value; permissionTasks[type] = nil
            return allowed && !Task.isCancelled
        default: return false
        }
    }
}

struct KokoHostedRoomContainer: UIViewRepresentable {
    @ObservedObject var session: KokoHostedRoomSession
    func makeUIView(context: Context) -> UIView {
        let container = UIView(); container.backgroundColor = .clear
        attach(to: container); return container
    }
    func updateUIView(_ uiView: UIView, context: Context) { attach(to: uiView) }
    private func attach(to container: UIView) {
        guard let view = session.webView else { container.subviews.forEach { $0.removeFromSuperview() }; return }
        if view.superview !== container {
            container.subviews.forEach { $0.removeFromSuperview() }
            view.removeFromSuperview(); view.translatesAutoresizingMaskIntoConstraints = false; container.addSubview(view)
            NSLayoutConstraint.activate([view.leadingAnchor.constraint(equalTo: container.leadingAnchor), view.trailingAnchor.constraint(equalTo: container.trailingAnchor), view.topAnchor.constraint(equalTo: container.topAnchor), view.bottomAnchor.constraint(equalTo: container.bottomAnchor)])
        }
        session.mountedContainer()
    }
}
