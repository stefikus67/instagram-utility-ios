# Milestone 2 — Website Product Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Turn the M1 shell into the real website-based product: Instagram's own mobile site inside `WKWebView`, made focused by an expanded route firewall, a network-level content blocker, and injected CSS/JS — with a working Find people search field, a DM-reel scroll lock, story posting, and an unread-only toggle. Remove the dead M1 native-inbox code.

**Architecture:** Three native Espresso tabs (Messages · Find people · You) share one background-preloaded `WKWebView`. Navigation is gated by `InstagramRoutePolicy` (pure Swift, expanded here) plus a compiled `WKContentRuleList` that blocks feed/Explore/Reels/ads/trackers at the network layer. Injected `WKUserScript`s hide Instagram's nav chrome, lock a DM-opened reel against scrolling to the next, override `screen.orientation` for story posting, and drive an unread-only inbox toggle. No token reading, no request replay, no data scraping — only client-side control of a page the user loaded themselves.

**Tech Stack:** Swift 5.9, SwiftUI (iOS 16), WebKit (`WKWebView`, `WKContentRuleList`, `WKUserScript`), XCTest, XcodeGen, GitHub Actions `macos-latest`. No third-party deps.

**Spec:** `docs/superpowers/specs/2026-10-05-instagram-utility-v1-design.md` — **read §A (the 2026-10-05 pm pivot) first; it overrides §5.** Endpoint notes (context only, not an API to call): `docs/notes/instagram-endpoints.md`.

## Global Constraints

- €0; public-repo `macos-latest` CI; unsigned IPA via SideStore. iOS 16.0, iPhone only, dark UI (`UIUserInterfaceStyle: Dark`).
- **No native Instagram API / no internal-endpoint calls / no session-token reading / no request replay / no scraping data out of the page.** Injected JS may only: hide/show elements, control navigation and scrolling, override `screen.orientation`, and toggle a read/unread CSS class. If a task seems to need more, stop and report.
- Never handle the password (login is Instagram's own page). Never log, display or commit cookies, session ids, tokens or user data; only the cookie *name* `sessionid` may be checked.
- Feed / Explore / global Reels feed must be unreachable by navigation **and** blocked by the content rule list.
- Every colour/size in **native** views comes from `Theme`/`Spacing`/`Metrics`/`Radius`/`TypeScale` (opacity multipliers allowed). Token drift tests must stay green. (Injected CSS that styles Instagram's own DOM is exempt — it is not a native view — but keep it minimal and let it fail gracefully.)
- Injected JS is defensive: every selector lookup is null-guarded, wrapped in try/catch, and re-applied on SPA route changes (Instagram is a single-page app). A missing element never throws.
- Commit messages end with the `Co-Authored-By:` trailer this session's instructions specify.
- Report files to the owner as full `C:\Users\stepa\Desktop\AI\active\instagram-utility-ios\...` paths or via the reveal-in-Explorer tool — never relative links, never "open in VS Code".

## How to run things

**Local Swift tests (Windows host, WSL toolchain already installed):**
```bash
wsl -d Ubuntu -- bash -c 'export PATH=$HOME/swift/usr/bin:/usr/bin:/bin LD_LIBRARY_PATH=$HOME/swiftlibs; rm -rf ~/iu && mkdir ~/iu && cp -r /mnt/c/Users/stepa/Desktop/AI/active/instagram-utility-ios/{Package.swift,Sources,Tests} ~/iu/ && cd ~/iu && swift test 2>&1 | tail -20'
```
Add `--filter <TestClass>` after `swift test` for a focused run. M1 baseline: 53 tests, 0 failures.

**App build (CI only — no local iOS compiler):**
```bash
cd /c/Users/stepa/Desktop/AI/active/instagram-utility-ios && git push && sleep 10 && "/c/Program Files/GitHub CLI/gh.exe" run watch "$("/c/Program Files/GitHub CLI/gh.exe" run list --branch m2-website --limit 1 --json databaseId --jq '.[0].databaseId')" --exit-status
```
On failure: `"/c/Program Files/GitHub CLI/gh.exe" run view <id> --log-failed | grep -E "error:" | head -40`, fix minimally, commit, push, re-watch.

## Deterministic vs device-verified

Pure-Swift tasks (1, 2, 7) are fully TDD'd and CI-proven. The WebKit/JS tasks (3–6) can be compiled in CI but their real behaviour (DOM hiding, reel-scroll lock, story posting) **can only be confirmed on the iPhone**. Those tasks ship with precise specs and defensive JS; the device checklist in Task 8 is their acceptance gate. Never mark a JS behaviour "working" from CI alone.

## File structure after this plan

```
Sources/
  RoutePolicy/InstagramRoutePolicy.swift     EXPANDED: profile/stories/create allowed; media from profile|stories|direct
  RoutePolicy/InstagramHost.swift            (unchanged)
  DesignTokens/…                             (unchanged)
  Core/                                       TRIMMED: delete native-inbox DTOs/loader/cache; keep nothing unused
  WebAssets/ContentRules.swift               WKContentRuleList JSON builder (pure) — new pure target
  WebAssets/InjectedScripts.swift            WKUserScript source strings + which-surface-needs-which (new pure target)
  App/App/InstagramUtilityApp.swift          env objects trimmed (no InboxStore)
  App/App/RootView.swift                     3 tabs host WebSurface; login sheet; no sample inbox
  App/Web/WebSurface.swift                   the shared WKWebView host (renamed/replaces WebChat), applies rules+scripts
  App/Web/WebSurfaceController.swift         owns the webview, content-rule compile, navigation per tab
  App/Web/NavigationGuard.swift              (moved from WebChat) expanded for new categories + unread toggle bridge
  App/Web/InstagramWebView.swift             (moved from WebChat)
  App/Session/InstagramSession.swift         keeps session/login/reset; drives WebSurfaceController
  App/Session/LoginView.swift                (unchanged)
  App/FindPeople/FindPeopleView.swift        native search field -> navigate to /<username>/
  App/You/YouView.swift                      Story-post button, profile, unread default, settings, reset
  App/Messages/MessagesView.swift            hosts the web surface at /direct/inbox/ + unread toggle
  App/DesignSystem/…                         keep Theme/Controls/PillTabBar/Avatar; DELETE ChatCard, StoryCircle (native-inbox only)
  App/Diagnostics/DiagnosticsStore.swift     (unchanged, + lastBlockedSurface already present)
Tests/
  RoutePolicyTests/InstagramRoutePolicyTests.swift   + new cases
  WebAssetsTests/ContentRulesTests.swift             new
  WebAssetsTests/InjectedScriptsTests.swift          new
  (DELETE CoreTests for removed types; keep RelativeTimestamp tests only if the type is kept)
```

Deleted: `Sources/App/Inbox/*` (InboxView, InboxStore, SampleData, StoriesRow), the native-inbox parts of `Sources/Core/*`, `Sources/App/DesignSystem/ChatCard.swift`, `StoryCircle.swift`, and their tests.

---

### Task 1: Expand the route firewall

**Files:**
- Modify: `Sources/RoutePolicy/InstagramRoutePolicy.swift`
- Test: `Tests/RoutePolicyTests/InstagramRoutePolicyTests.swift` (add cases; keep existing)

**Interfaces:**
- Produces: `RouteCategory` gains `.profileAllowed = "PROFILE_ALLOWED"`, `.storiesAllowed = "STORIES_ALLOWED"`, `.createAllowed = "CREATE_ALLOWED"`; `.dmMediaAllowedOnce` is renamed in spirit to `.mediaAllowed = "MEDIA_ALLOWED"` (one case; reached from direct/profile/stories). All new cases are `isAllowedInApp == true`. `classify(_:from:)` signature unchanged.

- [ ] **Step 1: Write failing tests** — append to `InstagramRoutePolicyTests.swift`:

```swift
    // M2: profiles
    func testProfileAllowed() {
        XCTAssertEqual(c("https://www.instagram.com/someone/"), .profileAllowed)
        XCTAssertEqual(c("https://www.instagram.com/someone/reels/"), .profileAllowed)   // their own reels grid
        XCTAssertEqual(c("https://www.instagram.com/someone/tagged/"), .profileAllowed)
    }
    func testFeedAndDiscoveryStillBlocked() {
        XCTAssertEqual(c("https://www.instagram.com/"), .blocked)
        XCTAssertEqual(c("https://www.instagram.com/explore/"), .blocked)
        XCTAssertEqual(c("https://www.instagram.com/reels/"), .blocked)            // global reels feed
        XCTAssertEqual(c("https://www.instagram.com/explore/search/keyword/?q=x"), .blocked)
    }
    // M2: stories
    func testStoriesAllowed() {
        XCTAssertEqual(c("https://www.instagram.com/stories/someone/"), .storiesAllowed)
        XCTAssertEqual(c("https://www.instagram.com/stories/someone/123/"), .storiesAllowed)
    }
    // M2: story creation / posting
    func testCreateAllowed() {
        XCTAssertEqual(c("https://www.instagram.com/create/story/"), .createAllowed)
        XCTAssertEqual(c("https://www.instagram.com/create/details/"), .createAllowed)
    }
    // M2: media reachable from profile and stories, not just DMs
    func testMediaFromProfile() {
        XCTAssertEqual(c("https://www.instagram.com/p/AAA/", from: "https://www.instagram.com/someone/"), .mediaAllowed)
        XCTAssertEqual(c("https://www.instagram.com/reel/AAA/", from: "https://www.instagram.com/someone/"), .mediaAllowed)
    }
    func testMediaFromStories() {
        XCTAssertEqual(c("https://www.instagram.com/p/AAA/", from: "https://www.instagram.com/stories/someone/1/"), .mediaAllowed)
    }
    func testMediaFromDirectStillAllowed() {
        XCTAssertEqual(c("https://www.instagram.com/reel/AAA/", from: "https://www.instagram.com/direct/t/1/"), .mediaAllowed)
    }
    func testMediaFromNowhereBlocked() {
        XCTAssertEqual(c("https://www.instagram.com/reel/AAA/"), .blocked)
        XCTAssertEqual(c("https://www.instagram.com/reel/AAA/", from: "https://www.instagram.com/accounts/login/"), .blocked)
    }
    func testMediaChainStillBlocked() {
        XCTAssertEqual(c("https://www.instagram.com/reel/BBB/", from: "https://www.instagram.com/reel/AAA/"), .blocked)
    }
    func testProfileIsAValidMediaSourceButDiscoveryIsNot() {
        // "/reels/" (feed) is never a valid source
        XCTAssertEqual(c("https://www.instagram.com/p/AAA/", from: "https://www.instagram.com/reels/"), .blocked)
    }
```
Update the existing `testMediaFromDirectAllowedOnce`, `testSameMediaQueryChangeAllowed`, `testMediaBackToDirectAllowed`, `testBlockedSurfaceLabels`, `testAllowedFlag`, and `testDirectRoutesAllowed`-adjacent cases that assert `.dmMediaAllowedOnce` to use `.mediaAllowed`. In `testUnknownInstagramRoutesBlocked`, **remove** the `/someone/` and `/stories/...` lines (now allowed); keep `/notifications/` and the 4-deep path as blocked.

- [ ] **Step 2: Run, verify RED** — `--filter InstagramRoutePolicyTests`; expect failures on the new cases / renamed enum.

- [ ] **Step 3: Implement.** Replace the enum and classify body:

```swift
enum RouteCategory: String, Equatable, CaseIterable {
    case authAllowed = "AUTH_ALLOWED"
    case directAllowed = "DIRECT_ALLOWED"
    case profileAllowed = "PROFILE_ALLOWED"
    case storiesAllowed = "STORIES_ALLOWED"
    case createAllowed = "CREATE_ALLOWED"
    case mediaAllowed = "MEDIA_ALLOWED"
    case blocked = "BLOCKED"
    case external = "EXTERNAL"

    var isAllowedInApp: Bool {
        switch self {
        case .authAllowed, .directAllowed, .profileAllowed, .storiesAllowed, .createAllowed, .mediaAllowed: return true
        case .blocked, .external: return false
        }
    }
}
```

In `classify`, after the auth check and before the media check, add:

```swift
        if first == "direct" { return .directAllowed }
        if isAuthPath(segs) { return .authAllowed }
        if first == "create" { return .createAllowed }
        if first == "stories" { return .storiesAllowed }
        if isMediaPath(segs) {
            guard let source = source else { return .blocked }
            let src = classify(source)
            let validSource: Set<RouteCategory> = [.directAllowed, .profileAllowed, .storiesAllowed]
            if validSource.contains(src) { return .mediaAllowed }
            if isMediaPath(segments(of: source)), sameRoute(source, url) { return .mediaAllowed }
            return .blocked
        }
        if isProfilePath(segs) { return .profileAllowed }
        return .blocked
```

Add the profile helper (a single non-reserved segment, optionally followed by `reels`/`tagged`/`reels/`):

```swift
    private static let reservedFirstSegments: Set<String> = [
        "explore", "reels", "direct", "accounts", "stories", "p", "reel", "tv",
        "create", "challenge", "auth_platform", "consent", "privacy",
        "notifications", "emails", "settings", "api", "graphql", "ajax",
    ]
    private static let profileSubpages: Set<String> = ["reels", "tagged", "saved", "feed"]

    /// A user profile: "/<username>/" or "/<username>/<reels|tagged|...>/". Never a reserved word.
    private static func isProfilePath(_ segs: [String]) -> Bool {
        guard let first = segs.first, !reservedFirstSegments.contains(first) else { return false }
        if segs.count == 1 { return true }
        if segs.count == 2 { return profileSubpages.contains(segs[1]) }
        return false
    }
```
Update `blockedSurface(for:)`'s `default` to still return `.profileOrOther`. Note `isMediaPath`'s existing `reserved` set already excludes profile sub-reel grids correctly (3-seg `/user/reel/code` handled there; 2-seg `/user/reels/` is a profile grid via `isProfilePath`). Keep `mediaTopLevel`/`mediaUnderUser` as-is.

- [ ] **Step 4: Run, verify GREEN** — full suite via WSL; all pass.
- [ ] **Step 5: Commit** `git add Sources/RoutePolicy Tests/RoutePolicyTests && git commit -m "Expand route firewall: profiles, stories, story creation, media from profile/stories"`

---

### Task 2: Content rule list (network-level firewall)

**Files:**
- Create: `Sources/WebAssets/ContentRules.swift`, `Tests/WebAssetsTests/ContentRulesTests.swift`
- Modify: `Package.swift` (add `WebAssets` target + `WebAssetsTests`)

**Interfaces:**
- Produces: `public enum ContentRules { public static let identifier = "ig-firewall-v1"; public static func json() -> String; public static let blockedURLPatterns: [String]; public static let blockedResourcePrefixes: [String] }`. The JSON is a valid `WKContentRuleList` source: an array of `{trigger:{url-filter,...}, action:{type:"block"}}` rules. Pure `String`/`Foundation` only.

- [ ] **Step 1: Package.swift** — add after the `Core` target and its test target:
```swift
        .target(name: "WebAssets", path: "Sources/WebAssets"),
        .testTarget(name: "WebAssetsTests", dependencies: ["WebAssets"], path: "Tests/WebAssetsTests"),
```

- [ ] **Step 2: Failing tests** — `Tests/WebAssetsTests/ContentRulesTests.swift`:
```swift
import XCTest
@testable import WebAssets

final class ContentRulesTests: XCTestCase {
    func testJSONIsValidArrayOfRules() throws {
        let data = Data(ContentRules.json().utf8)
        let obj = try JSONSerialization.jsonObject(with: data)
        let arr = try XCTUnwrap(obj as? [[String: Any]])
        XCTAssertFalse(arr.isEmpty)
        for rule in arr {
            let trigger = try XCTUnwrap(rule["trigger"] as? [String: Any])
            XCTAssertNotNil(trigger["url-filter"] as? String)
            let action = try XCTUnwrap(rule["action"] as? [String: Any])
            XCTAssertEqual(action["type"] as? String, "block")
        }
    }
    func testBlocksDiscoveryEndpoints() {
        let j = ContentRules.json()
        for needle in ["feed/timeline", "discover/web/explore_grid", "clips/discover", "discover/chaining", "reels_tray"] {
            XCTAssertTrue(j.contains(needle), "rule list must block \(needle)")
        }
    }
    func testEveryURLFilterIsAValidRegex() throws {
        let data = Data(ContentRules.json().utf8)
        let arr = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        for rule in arr {
            let f = (rule["trigger"] as? [String: Any])?["url-filter"] as? String ?? ""
            XCTAssertNoThrow(try NSRegularExpression(pattern: f), "bad url-filter regex: \(f)")
        }
    }
    func testDoesNotBlockDirectOrGraphqlSend() {
        // The DM surface itself and message-send must never be blocked.
        for allowed in ["/direct/", "/api/graphql"] {
            XCTAssertFalse(ContentRules.blockedURLPatterns.contains { allowed.range(of: $0, options: .regularExpression) != nil && !$0.contains("explore") && !$0.contains("timeline") },
                           "must not block \(allowed)")
        }
    }
}
```

- [ ] **Step 3: Implement** — `Sources/WebAssets/ContentRules.swift`:
```swift
import Foundation

/// A WKContentRuleList source that blocks Instagram's feed/Explore/Reels/ads/tracking requests at the
/// network layer. This is the hard firewall under the route policy and the main speed win.
/// Patterns are url-filter regexes (WebKit's content-blocker dialect). Keep them anchored to Instagram
/// request paths so the DM surface (/direct/, /api/graphql message ops) is never caught.
public enum ContentRules {
    public static let identifier = "ig-firewall-v1"

    /// Request path fragments to block. Feed, Explore, Reels discovery, suggested/chaining, and ads.
    public static let blockedURLPatterns: [String] = [
        "/api/v1/feed/timeline",
        "/api/v1/feed/reels_tray",
        "/api/v1/discover/web/explore_grid",
        "/api/v1/clips/discover",
        "/api/v1/clips/home",
        "/discover/chaining",
        "/api/v1/discover/topical_explore",
        "/graphql.*PolarisFeedTimelineRootV2Query",
        "/graphql.*PolarisFeedRootPaginationCachedQuery",
        "/graphql.*PolarisStoriesV3AdsPoolQuery",
        "/graphql.*explore",
    ]

    /// Third-party tracking/telemetry hosts & paths (speed + privacy).
    public static let blockedResourcePrefixes: [String] = [
        "/ajax/bz",
        "/logging_client_events",
        "/api/v1/web/launcher/sync",
    ]

    public static func json() -> String {
        let all = blockedURLPatterns + blockedResourcePrefixes
        let rules = all.map { pattern -> [String: Any] in
            ["trigger": ["url-filter": escaped(pattern)], "action": ["type": "block"]]
        }
        let data = try! JSONSerialization.data(withJSONObject: rules, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    /// url-filter is a regex; escape the one metachar we use literally ("/") stays fine, but "." in a
    /// literal path should match a literal dot. Our patterns already use ".*" intentionally, so only
    /// escape a bare "." that is not part of ".*".
    private static func escaped(_ p: String) -> String {
        // Our patterns are authored as regex already; return as-is. Kept as a seam for future literals.
        p
    }
}
```
*(Note for implementer: the `.*` patterns rely on the url including the GraphQL friendly-name as a query param — if CI/device shows those don't match, fall back to blocking by the `doc_id`-less path only and rely on the route policy for GraphQL. Record what you chose.)*

- [ ] **Step 4: GREEN** — `--filter ContentRulesTests` then full suite.
- [ ] **Step 5: Commit** `git add Package.swift Sources/WebAssets/ContentRules.swift Tests/WebAssetsTests/ContentRulesTests.swift && git commit -m "Add content-rule-list firewall (network-level feed/explore/reels/ads block)"`

---

### Task 3: Injected scripts module

**Files:**
- Create: `Sources/WebAssets/InjectedScripts.swift`, `Tests/WebAssetsTests/InjectedScriptsTests.swift`

**Interfaces:**
- Produces: `public enum InjectedScripts { public static let hideChromeCSS: String; public static let routeGuardJS: String; public static let reelLockJS: String; public static let orientationFixJS: String; public static let unreadToggleJS: String; public static func documentStart() -> [String]; public static func documentEnd() -> [String] }`. Each is a JS/CSS source string. `documentStart()` returns scripts to inject at document start (orientation fix, route guard install), `documentEnd()` those after load (chrome CSS, reel lock, unread toggle installer). Pure strings — the WKUserScript wrapping happens in the app (Task 4).

- [ ] **Step 1: Failing tests** — `Tests/WebAssetsTests/InjectedScriptsTests.swift`:
```swift
import XCTest
@testable import WebAssets

final class InjectedScriptsTests: XCTestCase {
    func testScriptsAreNonEmpty() {
        XCTAssertFalse(InjectedScripts.hideChromeCSS.isEmpty)
        XCTAssertFalse(InjectedScripts.routeGuardJS.isEmpty)
        XCTAssertFalse(InjectedScripts.reelLockJS.isEmpty)
        XCTAssertFalse(InjectedScripts.orientationFixJS.isEmpty)
        XCTAssertFalse(InjectedScripts.unreadToggleJS.isEmpty)
    }
    func testJSIsDefensivelyWrapped() {
        for js in [InjectedScripts.routeGuardJS, InjectedScripts.reelLockJS, InjectedScripts.orientationFixJS, InjectedScripts.unreadToggleJS] {
            XCTAssertTrue(js.contains("try"), "JS must be wrapped in try/catch")
            XCTAssertTrue(js.contains("(function"), "JS must be an IIFE to avoid polluting globals")
        }
    }
    func testOrientationFixOverridesOrientation() {
        XCTAssertTrue(InjectedScripts.orientationFixJS.contains("orientation"))
    }
    func testNoTokenOrCredentialAccess() {
        // Guardrail: injected JS must not touch cookies, localStorage auth, or fb_dtsg.
        for js in [InjectedScripts.routeGuardJS, InjectedScripts.reelLockJS, InjectedScripts.orientationFixJS, InjectedScripts.unreadToggleJS, InjectedScripts.hideChromeCSS] {
            for banned in ["document.cookie", "fb_dtsg", "sessionid", "localStorage", "XMLHttpRequest", "fetch("] {
                XCTAssertFalse(js.contains(banned), "injected asset must not reference \(banned)")
            }
        }
    }
    func testBridgeMessageNamesAreStable() {
        XCTAssertTrue(InjectedScripts.routeGuardJS.contains("iuBlocked"))
    }
}
```

- [ ] **Step 2: Implement** — `Sources/WebAssets/InjectedScripts.swift`. Write each as an IIFE with try/catch; re-apply on SPA route changes by patching `history.pushState`/`replaceState` and a `popstate` listener (no polling). Key behaviours:
  - `hideChromeCSS`: hide Instagram's bottom nav bar and the feed/explore/reels affordances via stable attributes (`[role="menubar"]`, `nav[aria-label]`, links whose `href` starts `/explore`, `/reels/`). Hide-only; never restyle content. Example skeleton:
    ```javascript
    // hideChromeCSS (a CSS string, injected into a <style>)
    // nav a[href^="/explore/"], nav a[href^="/reels/"], nav a[href="/"] { display:none !important; }
    // div[role="menubar"] { display:none !important; } /* bottom tab bar */
    ```
  - `routeGuardJS`: on pushState/replaceState/popstate, read `location.pathname`; if it starts with a blocked prefix (`/explore`, `/reels/`, or is exactly `/`), call `window.webkit.messageHandlers.iuBlocked.postMessage(path)` so native can redirect. IIFE, try/catch, no network.
  - `reelLockJS`: when `location.pathname` matches `^/reel/` or `^/p/`, disable vertical scroll / wheel / touchmove on the reel container and intercept the "next" affordance so swiping/arrowing to another reel does nothing. Re-arm on route change. Pure DOM event prevention; never navigates.
  - `orientationFixJS`: define `screen.orientation.type`/`angle` getters returning portrait and dispatch an orientationchange — fixes `/create/story/`'s "rotate your device". document-start.
  - `unreadToggleJS`: expose `window.__iuSetUnreadOnly(bool)` that adds/removes a `data-iu-unread-only` attribute on `<html>`; paired CSS (in `hideChromeCSS` or its own string) hides read inbox rows when the attribute is set. Read/unread detected by a stable marker on the row (the unread dot element); if none found, the toggle is a no-op (documented).

- [ ] **Step 3: GREEN** — `--filter InjectedScriptsTests`, full suite.
- [ ] **Step 4: Commit** `git add Sources/WebAssets/InjectedScripts.swift Tests/WebAssetsTests/InjectedScriptsTests.swift && git commit -m "Add injected CSS/JS assets (chrome-hide, route guard, reel lock, orientation fix, unread toggle)"`

---

### Task 4: Remove dead M1 native-inbox code

**Files:**
- Delete: `Sources/App/Inbox/{InboxView,InboxStore,SampleData,StoriesRow}.swift`, `Sources/App/DesignSystem/{ChatCard,StoryCircle}.swift`, and in `Sources/Core` the native-inbox types (`Models.swift`'s `ThreadSummary`/`InboxSnapshot`/`InboxSource`, `InboxOrdering.swift`, `InboxSearch.swift`, `InboxLoader.swift`, `DiskCache.swift`). Keep `RelativeTimestamp.swift` only if still referenced; otherwise delete it and its tests.
- Delete the matching tests under `Tests/CoreTests/`.
- Modify: `Sources/App/App/InstagramUtilityApp.swift` (drop `InboxStore` env object), `project.yml` if a source dir is removed, `Package.swift` if `Core`/`CoreTests` become empty (if `RelativeTimestamp` is kept, keep the target; if everything is deleted, remove the `Core` + `CoreTests` targets).

**Interfaces:** none produced; this is a clean removal. After it, nothing references `InboxStore`, `ThreadSummary`, `ChatCard`, `StoryCircle`, `AppCache` (delete `AppCache.swift` too — it only served the inbox cache).

- [ ] **Step 1:** `git rm` the files above. Decide `Core`'s fate: grep for `RelativeTimestamp`, `DiskCache` usage across `Sources/App`. If unused, remove the `Core`/`CoreTests` targets from `Package.swift` and delete `Sources/Core` + `Tests/CoreTests`. Record the decision.
- [ ] **Step 2:** Fix every resulting compile reference (InstagramUtilityApp env objects; any `import`/usage). The app should build to a shell with three tabs whose bodies are placeholders or the existing web view.
- [ ] **Step 3:** Local `swift test` passes (fewer tests now — that's expected; note the new count). Push; CI must compile.
- [ ] **Step 4: Commit** `git commit -m "Remove dead M1 native-inbox code (sample inbox, DTOs, cache, ChatCard/StoryCircle)"`

---

### Task 5: Web surface controller + three-tab wiring

**Files:**
- Move: `Sources/App/WebChat/*` → `Sources/App/Web/*` (`InstagramWebView.swift`, `NavigationGuard.swift`; `WebChatView.swift` → `WebSurface.swift`).
- Create: `Sources/App/Web/WebSurfaceController.swift`, `Sources/App/Messages/MessagesView.swift`.
- Modify: `Sources/App/Session/InstagramSession.swift`, `Sources/App/App/RootView.swift`, `Sources/App/Web/NavigationGuard.swift`.

**Interfaces:**
- `WebSurfaceController` (`@MainActor ObservableObject`): owns the single `WKWebView`; compiles+attaches `WKContentRuleList` from `ContentRules.json()` (async, cached by identifier); installs `WKUserScript`s from `InjectedScripts.documentStart()/documentEnd()`; registers the `iuBlocked` script-message handler → redirect to inbox; `func show(_ surface: Surface)` where `Surface` is `.messages`/`.profile(username:)`/`.create`/`.you`; `@Published var isReady`. Consumes `InstagramRoutePolicy`, `ContentRules`, `InjectedScripts`.
- `NavigationGuard` expanded: allow the new categories; on a blocked SPA route (from the `iuBlocked` bridge or URL KVO) redirect to the last allowed non-media page (inbox for Messages). Media still one-shot via policy.

- [ ] **Step 1:** Move files with `git mv`; rename `WebChatView`→`WebSurface`. Update references.
- [ ] **Step 2:** Implement `WebSurfaceController`: build `WKWebViewConfiguration` with the compiled rule list (`WKContentRuleList.compile` / `lookUpContentRuleList` cache) and `userContentController` scripts + `iuBlocked` handler. Reuse the persistent data store from `InstagramSession` (keep one web view — `InstagramSession` may own it and hand it to the controller, or the controller owns it and session reads cookies from it; pick one and keep login/reset working).
- [ ] **Step 3:** `RootView`: three tabs. Messages → `MessagesView` (web at `/direct/inbox/`). Find people → `FindPeopleView` (Task 6). You → `YouView`. The web view is shared and re-pointed per tab via `show(_:)`; keep the login sheet gated on `authState == .loggedOut && !<web presented>` logic from M1. Background-preload the inbox at launch for speed.
- [ ] **Step 4:** Local tests pass; push; CI green. (Behaviour is device-verified in Task 8.)
- [ ] **Step 5: Commit** `git commit -m "Add web surface controller; wire three tabs to the shared web view with firewall + scripts"`

---

### Task 6: Find people search field

**Files:**
- Modify: `Sources/App/FindPeople/FindPeopleView.swift`
- Create: `Sources/WebAssets/UsernameInput.swift` + `Tests/WebAssetsTests/UsernameInputTests.swift` (pure parsing)

**Interfaces:**
- `public enum UsernameInput { public static func profileURL(for raw: String) -> URL? }` — trims, strips a leading `@`, lowercases, rejects empties/spaces/invalid chars, returns `https://www.instagram.com/<username>/`. Pure, testable.
- `FindPeopleView`: a native `SearchField` (reuse `Controls.SearchField`) + submit → `controller.show(.profile(username:))`. Shows recent lookups is out of scope.

- [ ] **Step 1: Failing tests** — `UsernameInputTests`: `@user` → `.../user/`; `"  User "` → `.../user/`; `"a b"` → nil; `""` → nil; `"user.name_1"` → `.../user.name_1/`; a full URL paste `https://instagram.com/user/` → `.../user/`.
- [ ] **Step 2: Implement** `UsernameInput` (full code the implementer writes from the test contract; it is small and deterministic).
- [ ] **Step 3:** `FindPeopleView` native field; on submit navigate. Keyboard up on appear.
- [ ] **Step 4:** Tests + CI green.
- [ ] **Step 5: Commit** `git commit -m "Find people: native username search field navigating to profiles"`

---

### Task 7: Unread toggle, story-post button, You screen

**Files:**
- Modify: `Sources/App/Messages/MessagesView.swift` (unread toggle in the header → `controller` evaluates `__iuSetUnreadOnly`), `Sources/App/You/YouView.swift` (Post a story → `show(.create)`; keep diagnostics + Reset; default unread persisted via `UserDefaults`).

- [ ] **Step 1:** Messages header gets an "Unread only" toggle (native control, Theme-styled). Toggling calls `controller.setUnreadOnly(Bool)` which runs `window.__iuSetUnreadOnly(...)` and persists to `UserDefaults` (survives relaunch — Sidedoor parity).
- [ ] **Step 2:** YouView: "Post a story" button → `controller.show(.create)`; "My profile" → `show(.profile(username: <self>))` only if the self-username is known from the page title/URL without reading tokens — else open `/accounts/edit/`-style self page via a stable path; if not cleanly available, omit "My profile" and note it. Keep Reset + Diagnostics rows.
- [ ] **Step 3:** CI green.
- [ ] **Step 4: Commit** `git commit -m "Unread-only toggle (persisted), story-post button, You screen"`

---

### Task 8: Docs, device checklist, handoff

**Files:** Modify `AGENTS.md`, `README.md`, `docs/IPHONE_INSTALL.md` (new §4 for M2), `NEXT_SESSION_HANDOFF.md`.

- [ ] **Step 1:** AGENTS.md — update architecture to website-based (§A), the no-internal-API / injected-JS-only rules, the new file map, and the "injected JS is defensive and device-verified" note.
- [ ] **Step 2:** `docs/IPHONE_INSTALL.md` §4 — replace with the M2 device checklist:
  1. Install the new IPA. Log in. Messages shows Instagram's inbox, no Instagram bottom nav bar visible.
  2. Try to reach Home/Explore/Reels (tap any links, type nothing). Each bounces back; Diagnostics "Blocked navigations" rises.
  3. Open a chat; send a text and a photo; keyboard doesn't cover the field; Send always visible.
  4. **Open a reel someone sent in a DM → it opens; swiping/scrolling does NOT move to another reel.** (The M1 failure.)
  5. Find people → type a username → their profile opens. Open one of their posts; it shows; you can't swipe to a stranger's post.
  6. Open the person's stories and highlights; watch a few; closing returns cleanly; no jump into discovery.
  7. You → Post a story → pick a photo → it does NOT say "rotate your device" → post it (delete after).
  8. Messages → Unread only → read chats hide; relaunch → toggle state remembered.
  9. Reset Instagram Session → login sheet returns.
  Note which steps involve injected JS (2,4,7,8) — if any fails, report exactly what you saw; those are selector-dependent and expected to need a follow-up tweak.
- [ ] **Step 3:** README status → M2. Handoff → what shipped, the device-checklist gate, and the known-fragile list (injected selectors, content-rule GraphQL matching) to re-verify after Instagram site changes.
- [ ] **Step 4:** Commit; push; record CI run id + artifact size in the handoff; commit that.

---

## Self-review checklist (run after writing, before execution)
1. Spec coverage: §A features → tasks? firewall(1,2), chrome-hide(3,5), find-people(6), reel-lock(3,5,dev), stories/profiles(1,5), posting(3,7), unread(3,7), speed(2,5). ✓
2. Placeholders: none ("TBD"/"handle errors" absent). JS tasks give approach + skeleton, not fake "implement later".
3. Type consistency: `RouteCategory.mediaAllowed` used uniformly; `WebSurfaceController.show(_:)`/`Surface` names consistent across tasks 5–7; `ContentRules`/`InjectedScripts` enum names stable.
4. Scope: one coherent milestone (website product). Device-only behaviours flagged as such, gated by Task 8.
