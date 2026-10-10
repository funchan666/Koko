import SwiftUI
import WebKit
import UIKit

@MainActor
final class KokoLegalReader: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    let webView: WKWebView
    @Published private(set) var loading = true
    @Published private(set) var failure: String?
    @Published private(set) var readingMode = true
    private let address: URL
    init(address: URL) {
        self.address = address
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.addUserScript(
            WKUserScript(source: KokoPolicyReadingStyle.script(enabled: true),
                         injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self; webView.uiDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 246 / 255, green: 249 / 255, blue: 243 / 255, alpha: 1)
        webView.scrollView.backgroundColor = webView.backgroundColor
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsBackForwardNavigationGestures = true
        reload()
    }
    func reload() { failure = nil; loading = true; webView.load(URLRequest(url: address, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 25)) }
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { loading = true; failure = nil }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript(KokoPolicyReadingStyle.script(enabled: readingMode)) { [weak self] _, _ in
            self?.loading = false
        }
    }
    func toggleReadingMode() {
        readingMode.toggle()
        webView.configuration.userContentController.removeAllUserScripts()
        webView.configuration.userContentController.addUserScript(
            WKUserScript(source: KokoPolicyReadingStyle.script(enabled: readingMode),
                         injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        webView.evaluateJavaScript(KokoPolicyReadingStyle.script(enabled: readingMode), completionHandler: nil)
    }
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
    var bottomContentInset: CGFloat = 0
    func makeUIView(context: Context) -> WKWebView { reader.webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.scrollView.contentInset.bottom = bottomContentInset
        uiView.scrollView.verticalScrollIndicatorInsets.bottom = bottomContentInset
    }
    static func dismantleUIView(_ uiView: WKWebView, coordinator: ()) { uiView.stopLoading(); uiView.navigationDelegate = nil; uiView.uiDelegate = nil }
}

struct KokoLegalWebPage: View {
    @Environment(\.kokoScreenInsets) private var screenInsets
    @EnvironmentObject private var journey: KokoAccessJourney
    let document: KokoLegalDocument
    let close: () -> Void
    @StateObject private var reader: KokoLegalReader
    init(document: KokoLegalDocument, close: @escaping () -> Void) {
        self.document = document; self.close = close
        _reader = StateObject(wrappedValue: KokoLegalReader(address: document.url))
    }
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    headerAction("Back", action: close)
                    Text(document == .terms ? "Terms" : "Privacy")
                        .font(.custom("AvenirNext-DemiBold", size: 18, relativeTo: .headline))
                        .foregroundStyle(KokoWelcomePalette.paper)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(document.title).accessibilityAddTraits(.isHeader)
                    headerAction("Reload") { reader.reload() }
                }
                HStack {
                    Text(reader.readingMode ? "Reading view" : "Original webpage")
                        .font(.custom("AvenirNext-Regular", size: 11, relativeTo: .caption))
                        .foregroundStyle(KokoWelcomePalette.quiet)
                    Spacer(minLength: 8)
                    headerAction(reader.readingMode ? "View original" : "Reading view") {
                        reader.toggleReadingMode()
                    }
                }
            }
            .padding(.horizontal, 22).padding(.top, screenInsets.top + 4).padding(.bottom, 4)
            .background(KokoWelcomePalette.backdrop)
            ZStack {
                KokoLegalWebSurface(reader: reader, bottomContentInset: screenInsets.bottom + 16)
                    .accessibilityHidden(reader.loading || reader.failure != nil)
                if let failure = reader.failure {
                    readerState(title: "Couldn't open this page.", detail: failure, retry: true)
                } else if reader.loading {
                    readerState(title: "Opening your document…", detail: "", retry: false)
                }
            }
        }.background(KokoWelcomePalette.paper.ignoresSafeArea(.container))
            .onAppear { journey.showsPolicyReader = true }
            .onDisappear { journey.showsPolicyReader = false }
    }
    private func headerAction(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.custom("AvenirNext-DemiBold", size: 12, relativeTo: .subheadline))
                .foregroundStyle(KokoWelcomePalette.mint)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minWidth: 44, minHeight: 44)
        }.buttonStyle(KokoPressStyle())
    }
    private func readerState(title: String, detail: String, retry: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.custom("AvenirNext-Bold", size: 24, relativeTo: .title2))
            if !detail.isEmpty {
                Text(detail).font(.custom("AvenirNext-Regular", size: 14, relativeTo: .body))
                    .foregroundStyle(KokoInk.secondary)
            }
            if retry { KokoWelcomeAction(title: "Try again", primary: true) { reader.reload() } }
        }
        .foregroundStyle(KokoInk.primary).padding(28).frame(maxWidth: 420)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(KokoWelcomePalette.paper)
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
    @Environment(\.kokoScreenInsets) private var screenInsets
    let dismiss: () -> Void
    let open: (KokoLegalDocument) -> Void
    @AccessibilityFocusState private var reminderFocused: Bool
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.62).ignoresSafeArea()
                    .onTapGesture(perform: dismiss)
                    .accessibilityHidden(true)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("One quick step.")
                            .font(.custom("AvenirNext-Bold", size: 27, relativeTo: .title2))
                            .tracking(-0.7)
                            .foregroundStyle(KokoWelcomePalette.paper)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityFocused($reminderFocused)
                        Text("Read and agree to both policies before continuing.")
                            .font(.custom("AvenirNext-Regular", size: 14, relativeTo: .body))
                            .foregroundStyle(KokoWelcomePalette.quiet)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(3)
                            .padding(.top, 12)
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 18) {
                                policyLink(.terms)
                                policyLink(.privacy)
                            }.fixedSize(horizontal: true, vertical: false)
                            VStack(alignment: .leading, spacing: 0) {
                                policyLink(.terms)
                                policyLink(.privacy)
                            }
                        }.padding(.top, 12)
                        KokoWelcomeAction(title: "Back to agreement", primary: true, action: dismiss)
                            .padding(.top, 20)
                    }
                    .padding(28)
                    .background {
                        Image("KokoConsentSurface")
                            .resizable(capInsets: EdgeInsets(top: 28, leading: 28, bottom: 28, trailing: 28))
                            .accessibilityHidden(true)
                    }
                    .frame(maxWidth: 360)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)
                    .padding(.top, screenInsets.top).padding(.bottom, screenInsets.bottom)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, dismiss)
        .onAppear { reminderFocused = true }
    }
    private func policyLink(_ document: KokoLegalDocument) -> some View {
        Button {
            dismiss()
            open(document)
        } label: {
            Text(document.title)
                .underline()
                .font(.custom("AvenirNext-DemiBold", size: 13, relativeTo: .subheadline))
                .foregroundStyle(KokoWelcomePalette.mint)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 44, alignment: .leading)
        }.buttonStyle(KokoPressStyle())
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
                Artwork(sheet: .navigation, tile: 11)
                    .frame(width: 30, height: 30)
                    .padding(24)
                    .background(KokoControlSurface())
                Text("Make yourself comfortable.").font(.custom("AvenirNext-Bold", size: 28))
                KokoConsentFooter(agreed: $agreed) { document = $0 }
                KokoAction(title: "Continue") {
                    guard agreed else { requiresConsent = true; return }
                    community.acceptCurrentPolicies()
                }
                KokoAction(title: "Sign out", emphasis: false) { community.signOut() }
            }.accessibilityHidden(requiresConsent || document != nil)
            if requiresConsent { KokoConsentRequiredPanel(dismiss: { requiresConsent = false }) { document = $0 } }
            if let document { KokoLegalWebPage(document: document) { self.document = nil }.id(document) }
        }
    }
}
