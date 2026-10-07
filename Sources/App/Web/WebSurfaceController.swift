import Foundation
import SwiftUI
import WebKit

/// Owns the one WKWebView that shows Instagram's mobile site, and everything that shapes it into this
/// product: the persistent data store (the login survives restarts), the content-rule firewall, the injected
/// scripts and the `iuBlocked` bridge. `NavigationGuard` (owned here) enforces InstagramRoutePolicy on every
/// navigation; `InstagramSession` consumes this controller for login/reset but never builds a web view itself.
///
/// The web view is shared: Messages, Find people and the login sheet all host this same instance, one at a
/// time, and the tabs re-point it with `show(_:)`.
@MainActor
final class WebSurfaceController: NSObject, ObservableObject {
    /// What the shared web view is pointed at.
    enum Surface: Equatable {
        case messages
        case profile(username: String)
        /// Instagram's own account-search page (/explore/search/): live suggestions, no explore grid.
        case search
        /// There is no web page for the You tab (it is native settings). Kept so callers have one vocabulary;
        /// it maps to the inbox because the signed-in username is not known without reading session data.
        case you
    }

    /// True once the content rule list has been attached (or its compile failed and we proceed without it,
    /// relying on the route policy alone). Loads requested earlier are queued and replayed at that moment.
    @Published private(set) var isReady = false
    /// Whether the network-level firewall is actually active. Shown in Settings diagnostics.
    @Published private(set) var contentRulesActive = false
    /// The inbox's "Unread only" filter. Persisted so it survives relaunch; re-applied after every page load
    /// because the injected script's state lives in the page and resets with it.
    @Published private(set) var unreadOnly: Bool
    private static let unreadOnlyKey = "iuUnreadOnly"

    let webView: WKWebView
    /// Set by the session. While signed out, a blocked "/" is just Instagram's login landing, so the
    /// `iuBlocked` handler does nothing (the login flow owns the screen) instead of redirecting in a loop.
    var isSignedOut: () -> Bool = { false }
    var onPageFinished: () -> Void = {}

    private let userContent: WKUserContentController
    private var navigationGuard: NavigationGuard!
    private var currentSurface: Surface?
    private var pendingURL: URL?
    private var prepareTask: Task<Void, Never>?

    init(diagnostics: DiagnosticsStore) {
        unreadOnly = UserDefaults.standard.bool(forKey: Self.unreadOnlyKey)
        let userContent = WKUserContentController()
        self.userContent = userContent

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.userContentController = userContent
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = .all
        // Present as mobile Safari so Instagram serves its normal mobile website.
        config.applicationNameForUserAgent = "Version/17.0 Mobile/15E148 Safari/604.1"

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = false
        webView.isOpaque = false
        webView.backgroundColor = UIColor(Theme.bg)
        self.webView = webView
        super.init()

        navigationGuard = NavigationGuard(webView: webView, diagnostics: diagnostics) { [weak self] in
            // A fresh document has lost the filter state; put the persisted choice back first.
            self?.reapplyUnreadOnly()
            self?.onPageFinished()
        }
        installScripts()
        let bridge = ScriptBridge()
        bridge.target = self
        userContent.add(bridge, name: Self.blockedMessageName)

        // Compile/attach the firewall right away; loads wait for it (see `load`).
        prepareTask = Task { [weak self] in await self?.attachContentRules() }
    }

    // MARK: - Public API

    /// Resolves once the content rule list is attached (or failed). `InstagramSession.start()` awaits this
    /// before the first load so the very first request already goes through the firewall.
    func prepare() async {
        await prepareTask?.value
    }

    /// Points the shared web view at a surface. Re-showing the surface already on screen is a no-op so a
    /// tab switch does not throw away an open conversation; pass `reload` to force it (e.g. "Inbox").
    func show(_ surface: Surface, reload: Bool = false) {
        if !reload, currentSurface == surface { return }
        guard let url = Self.url(for: surface) else { return }
        currentSurface = surface
        load(url)
    }

    /// Loads Instagram's own login page (signed out, or after Reset).
    func showLogin() {
        currentSurface = nil
        load(InstagramRoutePolicy.loginURL)
    }

    /// Forgets navigation history after a Reset so nothing from the old session is a redirect target.
    func resetNavigationState() {
        navigationGuard.reset()
        showLogin()
    }

    /// "Back to chat" after a one-shot DM media view.
    func returnToConversation() {
        navigationGuard.returnToLastDirect()
    }

    /// Silences the page when it is not on screen (audio playing, mic open) without navigating away.
    func silence() {
        webView.pauseAllMediaPlayback(completionHandler: nil)
        webView.setMicrophoneCaptureState(.none, completionHandler: nil)
        webView.setCameraCaptureState(.none, completionHandler: nil)
    }

    /// Toggles the inbox's unread-only filter (script exposed by InjectedScripts.unreadToggleJS) and
    /// remembers the choice across launches.
    func setUnreadOnly(_ on: Bool) {
        unreadOnly = on
        UserDefaults.standard.set(on, forKey: Self.unreadOnlyKey)
        applyUnreadOnly(on)
    }

    /// Re-sends the persisted choice to the current page (a no-op while the filter is off, which is the
    /// state of every freshly loaded page).
    func reapplyUnreadOnly() {
        guard unreadOnly else { return }
        applyUnreadOnly(true)
    }

    private func applyUnreadOnly(_ on: Bool) {
        webView.evaluateJavaScript("window.__iuSetUnreadOnly && window.__iuSetUnreadOnly(\(on ? "true" : "false"));",
                                   completionHandler: nil)
    }

    // MARK: - Surfaces

    private static func url(for surface: Surface) -> URL? {
        switch surface {
        case .messages, .you: return InstagramRoutePolicy.inboxURL
        case .profile(let username): return InstagramRoutePolicy.profileURL(username: username)
        case .search: return InstagramRoutePolicy.searchURL
        }
    }

    private func load(_ url: URL) {
        guard isReady else { pendingURL = url; return }
        webView.load(URLRequest(url: url))
    }

    // MARK: - Content rules

    private static let blockedMessageName = "iuBlocked"

    private func attachContentRules() async {
        let list = await Self.contentRuleList()
        if let list { userContent.add(list) }
        contentRulesActive = list != nil
        isReady = true
        if let url = pendingURL {
            pendingURL = nil
            webView.load(URLRequest(url: url))
        }
    }

    /// The firewall rule list: looked up by identifier (cached on disk by WebKit), compiled on first use.
    /// Bump `ContentRules.identifier` whenever the rules change, or the stale cached list keeps winning.
    private static func contentRuleList() async -> WKContentRuleList? {
        guard let store = WKContentRuleListStore.default() else { return nil }
        let id = ContentRules.identifier
        let cached: WKContentRuleList? = await withCheckedContinuation { cont in
            store.lookUpContentRuleList(forIdentifier: id) { list, _ in cont.resume(returning: list) }
        }
        if let cached { return cached }
        return await withCheckedContinuation { cont in
            store.compileContentRuleList(forIdentifier: id, encodedContentRuleList: ContentRules.json()) { list, _ in
                cont.resume(returning: list)
            }
        }
    }

    // MARK: - Scripts

    /// Every script is main-frame-only: a sub-frame (captcha, login widget) must never run the route guard
    /// or reel lock, so its pathname can never post to `iuBlocked`.
    private func installScripts() {
        for js in InjectedScripts.documentStart() {
            userContent.addUserScript(WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }
        // hideChromeCSS is a stylesheet, not a script: it is wrapped into a <style> element here.
        for js in InjectedScripts.documentEnd() + [InjectedScripts.styleInjectionJS()] {
            userContent.addUserScript(WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        }
    }

    // MARK: - iuBlocked bridge

    fileprivate func handleBlocked(path: String) {
        guard !isSignedOut() else { return }
        navigationGuard.handleBlockedPath(path)
    }
}

/// Receives `iuBlocked` posts from the injected route guard. Weak target: WKUserContentController retains
/// its handlers, so a strong reference back to the controller would be a retain cycle.
@MainActor
private final class ScriptBridge: NSObject, WKScriptMessageHandler {
    weak var target: WebSurfaceController?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, let path = message.body as? String else { return }
        target?.handleBlocked(path: path)
    }
}
