import Foundation
import WebKit

enum AuthenticationState: String {
    case unknown = "Unknown"
    case loggedOut = "Logged out"
    case authenticated = "Logged in"
}

/// Owns the one WKWebView that holds the Instagram login (persistent data store, so the session
/// survives restarts). Credentials are typed into Instagram's own page; this class never sees them.
/// The same web view backs the login sheet and the web chat fallback — never both at once.
@MainActor
final class InstagramSession: NSObject, ObservableObject, WKHTTPCookieStoreObserver {
    @Published private(set) var authState: AuthenticationState = .unknown
    @Published var webChatPresented = false
    let diagnostics = DiagnosticsStore()
    let webView: WKWebView
    private var navigationGuard: NavigationGuard?
    private var started = false

    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = .all
        // Present as mobile Safari so Instagram serves its normal mobile website.
        config.applicationNameForUserAgent = "Version/17.0 Mobile/15E148 Safari/604.1"
        webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = false
        webView.isOpaque = false
        webView.backgroundColor = .black
        super.init()
        navigationGuard = NavigationGuard(webView: webView, diagnostics: diagnostics) { [weak self] in
            Task { await self?.refreshAuthState() }
        }
        // Login completes inside Instagram's single-page app without a full page load, so watch cookies.
        webView.configuration.websiteDataStore.httpCookieStore.add(self)
    }

    /// Called once at launch. Shows the login page only if there is no session.
    func start() async {
        guard !started else { return }
        started = true
        await refreshAuthState()
        if authState == .loggedOut {
            webView.load(URLRequest(url: InstagramRoutePolicy.loginURL))
        }
    }

    func openWebChat() {
        loadInbox()
        webChatPresented = true
    }

    func loadInbox() {
        webView.load(URLRequest(url: InstagramRoutePolicy.inboxURL))
    }

    /// Returns to the last conversation (used to leave a DM-media page in web chat).
    func backToConversation() {
        navigationGuard?.returnToLastDirect()
    }

    /// Only checks that a session cookie exists (by name); the value is never stored, shown or logged.
    func refreshAuthState() async {
        let cookies: [HTTPCookie] = await withCheckedContinuation { cont in
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cont.resume(returning: $0) }
        }
        let has = cookies.contains {
            let d = $0.domain.hasPrefix(".") ? String($0.domain.dropFirst()) : $0.domain
            return (d == "instagram.com" || d.hasSuffix(".instagram.com")) && $0.name == "sessionid" && !$0.value.isEmpty
        }
        let newState: AuthenticationState = has ? .authenticated : .loggedOut
        if newState != authState { authState = newState }
    }

    nonisolated func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        Task { @MainActor in await self.refreshAuthState() }
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
