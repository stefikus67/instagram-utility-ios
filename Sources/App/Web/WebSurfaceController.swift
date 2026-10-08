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
        /// The signed-in user's own profile. Needs `ownUsername` (auto-detected or typed); `show` does nothing
        /// until it is known.
        case ownProfile
        /// Instagram's home page with its feed hidden, used only while the story composer cover is open.
        case composer
    }

    /// True once the content rule list has been attached (or its compile failed and we proceed without it,
    /// relying on the route policy alone). Loads requested earlier are queued and replayed at that moment.
    @Published private(set) var isReady = false
    /// Whether the network-level firewall is actually active. Shown in Settings diagnostics.
    @Published private(set) var contentRulesActive = false
    /// The signed-in account's username, read from Instagram's own nav by `InjectedScripts.ownProfileJS`
    /// (or typed in as a fallback). Persisted so the You tab works straight after relaunch.
    @Published private(set) var ownUsername: String?
    private static let ownUsernameKey = "iuOwnUsername"
    /// True while the full-screen story composer is up. The cover binds to it, and the login sheet must not
    /// stack on top of it. Set only by `startComposer()` / `endComposer()`.
    @Published private(set) var composerOpen = false
    /// Shown over the composer when the script could not find Instagram's + button; nil otherwise.
    @Published private(set) var composerHint: String?

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
        ownUsername = UserDefaults.standard.string(forKey: Self.ownUsernameKey)
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
            self?.pageFinished()
        }
        // Deferred a turn: the guard fires this from inside a navigation callback, and ending the composer loads a page.
        navigationGuard.onComposerFinished = { [weak self] in
            Task { @MainActor in self?.endComposer() }
        }
        installScripts()
        let bridge = ScriptBridge()
        bridge.target = self
        userContent.add(bridge, name: Self.blockedMessageName)
        let ownBridge = OwnUsernameBridge()
        ownBridge.target = self
        userContent.add(ownBridge, name: Self.ownUsernameMessageName)
        let composerBridge = ComposerBridge()
        composerBridge.target = self
        userContent.add(composerBridge, name: Self.composerMessageName)

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
        // While the composer is up it owns the web view; a tab's onAppear must not re-point it.
        if composerOpen && surface != .composer { return }
        if !reload, currentSurface == surface { return }
        guard let url = self.url(for: surface) else { return }
        currentSurface = surface
        load(url)
    }

    /// Loads Instagram's own login page (signed out, or after Reset).
    func showLogin() {
        currentSurface = nil
        load(InstagramRoutePolicy.loginURL)
    }

    /// Forgets navigation history after a Reset so nothing from the old session is a redirect target.
    /// Also forgets the detected username: Reset means a possibly different account.
    func resetNavigationState() {
        navigationGuard.reset()
        composerOpen = false
        composerHint = nil
        ownUsername = nil
        UserDefaults.standard.removeObject(forKey: Self.ownUsernameKey)
        showLogin()
    }

    /// "Back to chat" after a one-shot DM media view.
    func returnToConversation() {
        navigationGuard.returnToLastDirect()
    }

    /// Opens the story composer: allows Instagram's home page (feed hidden by CSS) and, once it has loaded,
    /// has the injected script tap Instagram's own + button. The user picks Story and posts in Instagram's own UI.
    func startComposer() {
        composerHint = nil
        navigationGuard.composerMode = true
        composerOpen = true
        show(.composer, reload: true)
    }

    /// Closes the composer (X button, or the navigation guard saw the post finish) and returns to Messages.
    func endComposer() {
        guard composerOpen else { return }
        composerOpen = false
        composerHint = nil
        navigationGuard.composerMode = false
        silence()
        show(.messages, reload: true)
    }

    /// Silences the page when it is not on screen (audio playing, mic open) without navigating away.
    func silence() {
        webView.pauseAllMediaPlayback(completionHandler: nil)
        webView.setMicrophoneCaptureState(.none, completionHandler: nil)
        webView.setCameraCaptureState(.none, completionHandler: nil)
    }

    /// Manual fallback for the own-profile username: trims, strips a leading "@", lowercases and validates
    /// with the route policy. Returns false (and changes nothing) if it is not a valid Instagram username.
    @discardableResult
    func setOwnUsername(_ raw: String) -> Bool {
        var name = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if name.hasPrefix("@") { name.removeFirst() }
        guard InstagramRoutePolicy.profileURL(username: name) != nil else { return false }
        ownUsername = name
        UserDefaults.standard.set(name, forKey: Self.ownUsernameKey)
        return true
    }

    // MARK: - Surfaces

    private func url(for surface: Surface) -> URL? {
        switch surface {
        case .messages: return InstagramRoutePolicy.inboxURL
        case .ownProfile: return ownUsername.flatMap { InstagramRoutePolicy.profileURL(username: $0) }
        case .profile(let username): return InstagramRoutePolicy.profileURL(username: username)
        case .search: return InstagramRoutePolicy.searchURL
        case .composer: return InstagramRoutePolicy.homeURL
        }
    }

    private func load(_ url: URL) {
        guard isReady else { pendingURL = url; return }
        webView.load(URLRequest(url: url))
    }

    // MARK: - Content rules

    private static let blockedMessageName = "iuBlocked"
    private static let ownUsernameMessageName = "iuOwnUsername"
    private static let composerMessageName = "iuComposer"

    private func pageFinished() {
        onPageFinished()
        guard navigationGuard.composerMode else { return }
        webView.evaluateJavaScript("window.__iuStartComposer && window.__iuStartComposer()", completionHandler: nil)
    }

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

    // MARK: - iuComposer bridge

    /// `opened`: the script tapped + (nothing to show). `notfound`: it could not, so tell the user to tap + themselves.
    fileprivate func handleComposer(result: String) {
        guard composerOpen else { return }
        switch result {
        case "opened": composerHint = nil
        case "notfound": composerHint = "Tap + at the top, then Story."
        default: break
        }
    }

    // MARK: - iuOwnUsername bridge

    /// Re-detection overwrites the stored name, which handles an account switch.
    fileprivate func handleOwnUsername(_ name: String) {
        setOwnUsername(name)
    }
}

/// Receives `iuComposer` posts from `InjectedScripts.composerJS`. Weak target, same reason as `ScriptBridge`.
@MainActor
private final class ComposerBridge: NSObject, WKScriptMessageHandler {
    weak var target: WebSurfaceController?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, let result = message.body as? String else { return }
        target?.handleComposer(result: result)
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

/// Receives `iuOwnUsername` posts from `InjectedScripts.ownProfileJS`. Weak target, same reason as `ScriptBridge`.
@MainActor
private final class OwnUsernameBridge: NSObject, WKScriptMessageHandler {
    weak var target: WebSurfaceController?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, let name = message.body as? String else { return }
        target?.handleOwnUsername(name)
    }
}
