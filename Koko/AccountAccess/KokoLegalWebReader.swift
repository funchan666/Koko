import SwiftUI
import WebKit

@MainActor
final class KokoLegalReader: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    let webView: WKWebView
    @Published private(set) var loading = true
    @Published private(set) var failure: String?
    private let address: URL
    init(address: URL) {
        self.address = address
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self; webView.uiDelegate = self
        webView.isOpaque = false; webView.backgroundColor = .clear
        webView.allowsBackForwardNavigationGestures = true
        reload()
    }
    func reload() { failure = nil; loading = true; webView.load(URLRequest(url: address, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 25)) }
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { loading = true; failure = nil }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { loading = false }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { fail(error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { fail(error) }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { loading = false; failure = "This document stopped loading. Please reload it." }
    private func fail(_ error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        loading = false; failure = "This document could not be loaded. Check your connection and try again."
    }
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url, url.scheme?.lowercased() == "https" else { decisionHandler(.cancel); return }
        if action.targetFrame == nil { decisionHandler(.cancel); webView.load(action.request); return }
        decisionHandler(.allow)
    }
    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse, decisionHandler: @escaping @MainActor (WKNavigationResponsePolicy) -> Void) {
        if let http = response.response as? HTTPURLResponse, http.statusCode >= 400 {
            loading = false; failure = "The policy page is unavailable right now. Please try again later."; decisionHandler(.cancel)
        } else { decisionHandler(.allow) }
    }
}

struct KokoLegalWebSurface: UIViewRepresentable {
    let reader: KokoLegalReader
    func makeUIView(context: Context) -> WKWebView { reader.webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    static func dismantleUIView(_ uiView: WKWebView, coordinator: ()) { uiView.stopLoading(); uiView.navigationDelegate = nil; uiView.uiDelegate = nil }
}

struct KokoLegalWebPage: View {
    let document: KokoLegalDocument
    let close: () -> Void
    @StateObject private var reader: KokoLegalReader
    init(document: KokoLegalDocument, close: @escaping () -> Void) {
        self.document = document; self.close = close
        _reader = StateObject(wrappedValue: KokoLegalReader(address: document.url))
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                KokoIconAction(icon: 5, label: "Back", action: close)
                Text(document.title).font(.custom("AvenirNext-Bold", size: 21))
                Spacer()
                Button("Reload") { reader.reload() }.font(.custom("AvenirNext-DemiBold", size: 13)).buttonStyle(.plain).frame(minWidth: 50, minHeight: 44)
            }.padding(.horizontal, 18).padding(.vertical, 10)
            if reader.loading { Text("Opening your document…").font(.custom("AvenirNext-Medium", size: 12)).padding(12) }
            ZStack {
                KokoLegalWebSurface(reader: reader)
                if let failure = reader.failure {
                    VStack(spacing: 18) {
                        Artwork(sheet: .arrival, tile: 3).frame(height: 140)
                        Text(failure).multilineTextAlignment(.center)
                        KokoAction(title: "Try again") { reader.reload() }
                    }.padding(24).background(ArtworkSurface()).padding(24)
                }
            }
        }.background(ArtworkBackdrop())
    }
}

struct KokoConsentFooter: View {
    @Binding var agreed: Bool
    let open: (KokoLegalDocument) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button { agreed.toggle() } label: {
                HStack(alignment: .center, spacing: 12) {
                    Text(agreed ? "YES" : "").font(.custom("AvenirNext-Bold", size: 10))
                        .frame(width: 36, height: 36).background(ArtworkSurface(tile: agreed ? 3 : 5))
                    Text("I have read and agree to both policies below.").font(.custom("AvenirNext-Medium", size: 12)).multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }.frame(minHeight: 48)
            }.buttonStyle(KokoPressStyle()).accessibilityLabel("Agree to Terms of Service and Privacy Policy").accessibilityValue(agreed ? "Selected" : "Not selected")
            HStack(spacing: 12) {
                Button("Terms of Service") { open(.terms) }
                Text("&")
                Button("Privacy Policy") { open(.privacy) }
            }.font(.custom("AvenirNext-DemiBold", size: 12)).buttonStyle(.plain).frame(minHeight: 44).padding(.leading, 4)
        }
    }
}

struct KokoConsentRequiredPanel: View {
    let dismiss: () -> Void
    let open: (KokoLegalDocument) -> Void
    var body: some View {
        KokoModal(title: "A shared space starts with trust.", dismiss: dismiss) {
            Artwork(sheet: .arrival, tile: 2).frame(height: 165)
            Text("Please read the Terms of Service and Privacy Policy, then tick the agreement below before continuing.").font(.custom("AvenirNext-Regular", size: 15))
            HStack {
                KokoAction(title: "Read terms", emphasis: false) { dismiss(); open(.terms) }
                KokoAction(title: "Read privacy", emphasis: false) { dismiss(); open(.privacy) }
            }
            KokoAction(title: "Back to the agreement") { dismiss() }
        }
    }
}

struct KokoConsentRenewalGate: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @State private var agreed = false
    @State private var document: KokoLegalDocument?
    @State private var requiresConsent = false
    var body: some View {
        ZStack {
            KokoPage(title: "Before we begin", subtitle: "Your saved space is still here.") {
                Artwork(sheet: .arrival, tile: 2).frame(height: 230)
                Text("Make yourself comfortable.").font(.custom("AvenirNext-Bold", size: 28))
                KokoConsentFooter(agreed: $agreed) { document = $0 }
                KokoAction(title: "Continue") {
                    guard agreed else { requiresConsent = true; return }
                    community.acceptCurrentPolicies()
                }
                KokoAction(title: "Sign out", emphasis: false) { community.signOut() }
            }
            if requiresConsent { KokoConsentRequiredPanel(dismiss: { requiresConsent = false }) { document = $0 } }
            if let document { KokoLegalWebPage(document: document) { self.document = nil }.id(document) }
        }
    }
}
