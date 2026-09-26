import Foundation
import WebKit

enum AuthenticationState: String {
    case unknown = "Unknown"
    case loggedOut = "Logged out"
    case authenticated = "Logged in"
}

/// Owns the one WKWebView and the persistent web session. Credentials are typed into
/// Instagram's own login page; this class never sees them.
@MainActor
final class InstagramSession: ObservableObject {
    @Published private(set) var authState: AuthenticationState = .unknown
    let diagnostics = DiagnosticsStore()
    let webView: WKWebView
    private var navigationGuard: NavigationGuard?
    private var started = false

    init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default() // persistent: session survives app restarts
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = .all
        // Present as mobile Safari so Instagram serves its normal mobile web experience.
        config.applicationNameForUserAgent = "Version/17.0 Mobile/15E148 Safari/604.1"
        webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = false
        navigationGuard = NavigationGuard(webView: webView, diagnostics: diagnostics) { [weak self] in
            Task { await self?.refreshAuthState() }
        }
    }

    func startIfNeeded() {
        guard !started else { return }
        started = true
        loadInbox()
    }

    func loadInbox() {
        webView.load(URLRequest(url: InstagramRoutePolicy.inboxURL))
    }

    /// Returns to the last conversation (used to leave a DM-media page).
    func backToConversation() {
        navigationGuard?.returnToLastDirect()
    }

    /// Only checks that a session cookie exists (by name); the value is never stored or shown.
    func refreshAuthState() async {
        let cookies: [HTTPCookie] = await withCheckedContinuation { cont in
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cont.resume(returning: $0) }
        }
        let has = cookies.contains { $0.domain.hasSuffix("instagram.com") && $0.name == "sessionid" && !$0.value.isEmpty }
        authState = has ? .authenticated : .loggedOut
    }

    /// Deliberate, user-confirmed logout: removes Instagram/Facebook web data only.
    func resetSession() async {
        let store = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        let records: [WKWebsiteDataRecord] = await withCheckedContinuation { cont in
            store.fetchDataRecords(ofTypes: types) { cont.resume(returning: $0) }
        }
        let needles = ["instagram", "facebook", "fbcdn"]
        let targets = records.filter { r in needles.contains { r.displayName.lowercased().contains($0) } }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            store.removeData(ofTypes: types, for: targets) { cont.resume() }
        }
        authState = .loggedOut
        navigationGuard?.reset()
        webView.load(URLRequest(url: InstagramRoutePolicy.loginURL))
    }
}
