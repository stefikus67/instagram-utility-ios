import UIKit
import WebKit

/// Enforces InstagramRoutePolicy on the web view. Instagram is a single-page app, so most in-app
/// route changes are history.pushState calls that never reach decidePolicyFor; we therefore also
/// observe WKWebView.url and hard-redirect away from any route the policy rejects.
@MainActor
final class NavigationGuard: NSObject, WKNavigationDelegate, WKUIDelegate {
    private weak var webView: WKWebView?
    private let diagnostics: DiagnosticsStore
    private let onPageFinished: () -> Void
    private var lastAllowedURL: URL?
    private var lastDirectURL: URL?
    private var urlObservation: NSKeyValueObservation?

    init(webView: WKWebView, diagnostics: DiagnosticsStore, onPageFinished: @escaping () -> Void) {
        self.webView = webView
        self.diagnostics = diagnostics
        self.onPageFinished = onPageFinished
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        urlObservation = webView.observe(\.url, options: [.new]) { [weak self] wv, _ in
            guard let url = wv.url else { return }
            Task { @MainActor in self?.handleObservedURL(url) }
        }
    }

    func reset() {
        lastAllowedURL = nil
        lastDirectURL = nil
    }

    func returnToLastDirect() {
        webView?.load(URLRequest(url: lastDirectURL ?? InstagramRoutePolicy.inboxURL))
    }

    // MARK: - SPA route changes (pushState) and committed URLs

    private func handleObservedURL(_ url: URL) {
        if let last = lastAllowedURL, last.absoluteString == url.absoluteString { return }
        let category = InstagramRoutePolicy.classify(url, from: lastAllowedURL)
        if category.isAllowedInApp {
            record(url, category)
        } else if category == .blocked {
            diagnostics.recordBlocked(url)
            webView?.stopLoading()
            returnToLastDirect()
        }
        // .external cannot be committed in the main frame (cancelled in decidePolicyFor).
    }

    private func record(_ url: URL, _ category: RouteCategory) {
        lastAllowedURL = url
        if category == .directAllowed { lastDirectURL = url }
        diagnostics.recordAllowed(url, category: category)
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        // Sub-frames (captcha, login widgets) are not user-visible navigation.
        if navigationAction.targetFrame?.isMainFrame == false { decisionHandler(.allow); return }

        let category = InstagramRoutePolicy.classify(url, from: lastAllowedURL)
        switch category {
        case .authAllowed, .directAllowed, .profileAllowed, .storiesAllowed, .createAllowed, .mediaAllowed:
            record(url, category)
            decisionHandler(.allow)
        case .blocked:
            diagnostics.recordBlocked(url)
            decisionHandler(.cancel)
            // A rejected first load (e.g. login redirecting to "/") must not leave a blank screen.
            if webView.url == nil || lastAllowedURL == nil { returnToLastDirect() }
        case .external:
            decisionHandler(.cancel)
            if navigationAction.navigationType == .linkActivated { openExternally(url) }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onPageFinished()
    }

    // MARK: - WKUIDelegate (target=_blank / window.open)

    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let url = navigationAction.request.url else { return nil }
        switch InstagramRoutePolicy.classify(url, from: lastAllowedURL) {
        case .external: openExternally(url)
        case .blocked: diagnostics.recordBlocked(url)
        default: webView.load(navigationAction.request)
        }
        return nil
    }

    /// Voice messages in web chat need the microphone. Only Instagram may ask; iOS still shows its prompt.
    func webView(_ webView: WKWebView,
                 requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo,
                 type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        let host = origin.host
        let isInstagram = origin.protocol == "https" && InstagramHost.isInstagram(host)
        decisionHandler(isInstagram ? .prompt : .deny)
    }

    private func openExternally(_ url: URL) {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else { return }
        UIApplication.shared.open(url)
    }
}
