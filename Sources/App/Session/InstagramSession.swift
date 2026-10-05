import Foundation
import WebKit

enum AuthenticationState: String {
    case unknown = "Unknown"
    case loggedOut = "Logged out"
    case authenticated = "Logged in"
}

/// Tracks whether there is an Instagram login, and drives login/reset. The one WKWebView (persistent data
/// store, so the session survives restarts) is owned by `WebSurfaceController`; this class only reads it
/// and points it at the login page. Credentials are typed into Instagram's own page and never seen here.
@MainActor
final class InstagramSession: NSObject, ObservableObject, WKHTTPCookieStoreObserver {
    @Published private(set) var authState: AuthenticationState = .unknown
    let diagnostics: DiagnosticsStore
    let surface: WebSurfaceController
    private var started = false

    var webView: WKWebView { surface.webView }

    override init() {
        let diagnostics = DiagnosticsStore()
        self.diagnostics = diagnostics
        surface = WebSurfaceController(diagnostics: diagnostics)
        super.init()
        surface.onPageFinished = { [weak self] in
            Task { await self?.refreshAuthState() }
        }
        surface.isSignedOut = { [weak self] in self?.authState == .loggedOut }
        // Login completes inside Instagram's single-page app without a full page load, so watch cookies.
        webView.configuration.websiteDataStore.httpCookieStore.add(self)
    }

    /// Called once at launch. Loads the login page if there is no session, otherwise preloads the inbox
    /// in the background so the Messages tab opens instantly. Waits for the content-rule firewall first.
    func start() async {
        guard !started else { return }
        started = true
        await surface.prepare()
        await refreshAuthState()
        if authState == .loggedOut {
            surface.showLogin()
        } else {
            surface.show(.messages)
        }
    }

    /// Only checks that a session cookie exists (by name); the value is never stored, shown or logged.
    func refreshAuthState() async {
        let cookies: [HTTPCookie] = await withCheckedContinuation { cont in
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cont.resume(returning: $0) }
        }
        let has = cookies.contains {
            InstagramHost.isInstagram($0.domain) && $0.name == "sessionid" && !$0.value.isEmpty
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
        surface.resetNavigationState()
    }
}
