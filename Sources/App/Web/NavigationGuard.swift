import UIKit
import WebKit

/// Enforces InstagramRoutePolicy on the web view. Instagram is a single-page app, so most in-app
/// route changes are history.pushState calls that never reach decidePolicyFor; we therefore also
/// observe WKWebView.url (and the `iuBlocked` script bridge, see WebSurfaceController) and hard-redirect
/// away from any route the policy rejects, back to the last allowed non-media page.
@MainActor
final class NavigationGuard: NSObject, WKNavigationDelegate, WKUIDelegate {
    private weak var webView: WKWebView?
    private let diagnostics: DiagnosticsStore
    private let onPageFinished: () -> Void
    private var lastAllowedURL: URL?
    /// Last allowed page that is a DM surface (used by "Back to chat" after a one-shot media view).
    private var lastDirectURL: URL?
    /// Last allowed page that is neither media nor auth: where a blocked route sends the user back to.
    private var lastSafeURL: URL?
    private var urlObservation: NSKeyValueObservation?
    /// A redirect we issued that has not finished loading yet. While set, a repeat redirect to the same
    /// target is ignored: that is what makes the pushState/replaceState/popstate bursts and the URL
    /// observer idempotent, and what stops a redirect loop.
    private var redirectInFlight: URL?
    private var redirectTimeout: Task<Void, Never>?

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
        lastSafeURL = nil
        clearRedirectInFlight()
    }

    func returnToLastDirect() {
        webView?.load(URLRequest(url: lastDirectURL ?? InstagramRoutePolicy.inboxURL))
    }

    /// Handles a blocked pathname reported by the injected route guard. The path is untrusted page
    /// input: it is re-classified here and ignored unless the policy itself says it is blocked.
    func handleBlockedPath(_ path: String) {
        guard path.hasPrefix("/"), let url = URL(string: "https://www.instagram.com" + path),
              InstagramRoutePolicy.classify(url, from: lastAllowedURL) == .blocked else { return }
        redirectToSafePage(counting: url)
    }

    // MARK: - SPA route changes (pushState) and committed URLs

    private func handleObservedURL(_ url: URL) {
        if let last = lastAllowedURL, last.absoluteString == url.absoluteString { return }
        let category = InstagramRoutePolicy.classify(url, from: lastAllowedURL)
        if category.isAllowedInApp {
            record(url, category)
        } else if category == .blocked {
            // Count and stop loading only if a redirect is actually issued; a repeat event for a redirect
            // already in flight must leave that redirect alone.
            redirectToSafePage(counting: url)
        }
        // .external cannot be committed in the main frame (cancelled in decidePolicyFor).
    }

    private func record(_ url: URL, _ category: RouteCategory) {
        lastAllowedURL = url
        if category == .directAllowed { lastDirectURL = url }
        if category != .mediaAllowed && category != .authAllowed { lastSafeURL = url }
        diagnostics.recordAllowed(url, category: category)
    }

    /// Sends the web view to the last allowed non-media page (the inbox if there is none).
    /// Does nothing (no stopLoading, no count) when an identical redirect is already loading, so a burst
    /// of blocked events cannot cancel the redirect that is already on its way. `blocked` is the URL that
    /// triggered it, counted in diagnostics once, only when a redirect is actually issued.
    private func redirectToSafePage(counting blocked: URL? = nil) {
        let target = lastSafeURL ?? InstagramRoutePolicy.inboxURL
        guard redirectInFlight != target else { return }
        if let blocked { diagnostics.recordBlocked(blocked) }
        redirectInFlight = target
        redirectTimeout?.cancel()
        // Safety net if the load never finishes (cancelled, offline): allow a later redirect again.
        redirectTimeout = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            self?.clearRedirectInFlight()
        }
        webView?.stopLoading()
        webView?.load(URLRequest(url: target))
    }

    private func clearRedirectInFlight() {
        redirectInFlight = nil
        redirectTimeout?.cancel()
        redirectTimeout = nil
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
        case .authAllowed, .directAllowed, .profileAllowed, .storiesAllowed, .createAllowed, .mediaAllowed, .searchAllowed:
            record(url, category)
            decisionHandler(.allow)
        case .blocked:
            diagnostics.recordBlocked(url)
            decisionHandler(.cancel)
            // A rejected first load (e.g. login redirecting to "/") must not leave a blank screen.
            if webView.url == nil || lastAllowedURL == nil { redirectToSafePage() }
        case .external:
            decisionHandler(.cancel)
            if navigationAction.navigationType == .linkActivated { openExternally(url) }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        clearRedirectInFlight()
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
