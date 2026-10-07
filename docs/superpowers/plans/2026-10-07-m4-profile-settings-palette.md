# M4 — Your profile, Settings tab, Instagram palette, nav cover

Owner decisions (2026-10-07):
- **Colours:** match Instagram's dark web theme so web pages and native parts read as one surface. Gold stays the accent.
  Measured on instagram.com (dark): `--ig-primary-background` 12,16,20 (#0C1014), `--ig-secondary-background`
  37,41,46 (#25292E), `--ig-elevated-background` 33,35,40 (#212328), `--ig-secondary-text` 168,168,168,
  `--ig-elevated-separator` 54,54,54.
- **Find people:** Instagram's own bottom nav (home/messages/search/reels/profile) is visible there — cover it.
- **You tab:** opens *my own Instagram profile*. Username is **auto-detected** from Instagram's page; manual entry is
  only the fallback.
- **Post a story:** removed entirely (it never worked; it dumped you on Find people).
- **Settings:** a **fourth tab** (gear) beside Messages · Find people · You, holding Diagnostics + Reset (+ username).

Branch: `m4-profile-settings`. Model split: Opus planned + reviews; Sonnet implements.

## Task 1 — Palette → Instagram dark (`Sources/DesignTokens/Colors.swift`, `Tests/DesignTokensTests/ColorTests.swift`)
Replace the `Palette` values (doc comment: "Instagram-matched dark (M4) — native chrome blends with IG's web pages"):
| token | new hex | note |
|---|---|---|
| bg | 0x0c1014 | IG primary background |
| card | 0x212328 | IG elevated background |
| raise | 0x25292e | IG secondary background (tab pill, icon buttons) |
| text | 0xffffff | |
| text2 | 0xdbdbdb | |
| text3 | 0xa8a8a8 | IG secondary text |
| placeholder | 0x8e8e8e | |
| gold / goldInk / coral | unchanged | |
| border | 0x363636 | IG elevated separator |
| seenRing | 0x3a3e44 | |
| avatarTop / avatarBottom | 0x3a3e44 / 0x25292e | |

- `testHexParsing`: keep but it may use any literal — leave as is (it doesn't reference Palette).
- `testMatchesValuesMeasuredDuringDesign`: recompute the three ratios for the new values with the `contrastRatio`
  function and pin them (accuracy 0.1). `testEveryTextPairMeetsMinimum` must still pass for every pair — if a pair
  fails, adjust only that text colour lighter, never the backgrounds.
- `WebSurfaceController.init`: `webView.backgroundColor = .black` → `UIColor(Theme.bg)` so a loading page shows the
  same navy, not black. (`import SwiftUI` if needed.)

## Task 2 — Remove story posting (app layer only)
- `YouView.swift`: delete the Stories section, `showCreator`, `storyCreator`, `openStoryCreator`, `closeStoryCreator`.
- `WebSurfaceController`: delete `Surface.create`, `desktopUserAgent`, `applyUserAgent(for:)` and its calls (UA stays
  nil = mobile everywhere), `isPresentedFullScreen`. `url(for:)` loses `.create`.
- `RootView.loginRequired`: becomes `session.authState == .loggedOut` (no full-screen exception any more).
- **Keep** `InstagramRoutePolicy` (`createAllowed`, `createStoryURL`) and `orientationFixJS` untouched — tested,
  harmless, and out of scope. Remove the "desktop UA for story posting" paragraphs from `AGENTS.md`/`CLAUDE.md`
  architecture text and say story posting was dropped in M4.

## Task 3 — Own-username auto-detection
### 3a. `InjectedScripts.ownProfileJS` (document-end; add to `documentEnd()` after `unreadToggleJS`)
Use exactly this script:
```js
(function(){
  try {
    if (window.__iuOwnProfileInstalled) { return; }
    window.__iuOwnProfileInstalled = true;

    // First path segments that are Instagram sections, never usernames.
    var RESERVED = ['explore','reels','reel','direct','accounts','create','stories','p','tv','about','legal',
      'developer','web','challenge','emails','session','graphql','api','oauth','privacy','terms','help',
      'directory','topics','locations','nametag','your_activity','notifications','lite','threads'];
    var sent = null;
    var observer = null;
    var timer = null;

    // Only the inbox: on someone else's profile, a nav-like container can link to *their* "/<name>/".
    function onInbox() {
      try { return ((window.location && window.location.pathname) || '').indexOf('/direct/') === 0; }
      catch (e) { return false; }
    }

    // The signed-in account's profile link lives in Instagram's own (hidden) navigation bar.
    function findOwnUsername() {
      try {
        var navs = document.querySelectorAll('[role="menubar"], nav, [role="navigation"]');
        for (var i = 0; i < navs.length; i++) {
          var links = navs[i].querySelectorAll('a[href]');
          for (var j = 0; j < links.length; j++) {
            var href = links[j].getAttribute('href') || '';
            var m = /^\/([A-Za-z0-9._]{1,30})\/?$/.exec(href);
            if (!m) { continue; }
            if (RESERVED.indexOf(m[1].toLowerCase()) >= 0) { continue; }
            return m[1];
          }
        }
      } catch (e) {}
      return null;
    }

    function report() {
      try {
        if (!onInbox()) { return; }
        var name = findOwnUsername();
        if (!name || name === sent) { return; }
        var wk = window.webkit;
        var handler = wk && wk.messageHandlers && wk.messageHandlers.iuOwnUsername;
        if (handler && typeof handler.postMessage === 'function') {
          handler.postMessage(String(name));
          sent = name;
          if (observer) { observer.disconnect(); observer = null; }
        }
      } catch (e) {}
    }

    function schedule() {
      try {
        if (timer) { return; }
        timer = setTimeout(function() { timer = null; report(); }, 300);
      } catch (e) {}
    }

    function wrap(name) {
      try {
        var original = window.history && window.history[name];
        if (typeof original !== 'function') { return; }
        window.history[name] = function() {
          var result = original.apply(this, arguments);
          schedule();
          return result;
        };
      } catch (e) {}
    }

    try {
      if (typeof MutationObserver === 'function' && document.body) {
        observer = new MutationObserver(schedule);
        observer.observe(document.body, { childList: true, subtree: true });
      }
    } catch (e) {}
    wrap('pushState');
    wrap('replaceState');
    window.addEventListener('popstate', schedule);
    schedule();
  } catch (e) {}
})();
```
Doc comment: reads only a link's `href` in Instagram's nav (no cookies, storage, network or IG data structures),
inbox-only, posts the username once per page to `iuOwnUsername`.

Tests (`InjectedScriptsTests`): add `ownProfileJS` to every guardrail list (non-empty, IIFE/try/catch, invoked-IIFE
suffix, banned-strings, no `setInterval`); new test: contains `iuOwnUsername`, `'/direct/'`, `menubar`, and does
**not** contain `cookie`/`localStorage`/`fetch(`; `testStartAndEndGroupings` → documentEnd
`[reelLockJS, unreadToggleJS, ownProfileJS]`. The JSContext parse test already covers `documentEnd()`.

### 3b. Native (`WebSurfaceController`)
- `@Published private(set) var ownUsername: String?`, persisted under UserDefaults key `iuOwnUsername`, loaded in init.
- Register a second `ScriptBridge`-style handler for `iuOwnUsername` (main frame only). On a message: accept only if
  `InstagramRoutePolicy.profileURL(username:) != nil`; then set + persist. (Re-detection overwrites — handles an
  account switch.)
- `func setOwnUsername(_ raw: String)` for the manual fallback: trim, strip a leading `@`, lowercase, validate the same
  way; returns `Bool`.
- `resetNavigationState()` also clears `ownUsername` (and the default) — Reset = new account.
- Surfaces: replace `.you` with `case ownProfile` that maps to `profileURL(username: ownUsername)`; if nil, `show`
  does nothing.

## Task 4 — Instagram nav cover (Find people + You)
- `Metrics.webNavCover: Double = 56` (IG's mobile nav is ~50pt + its top hairline; a few points of over-cover are
  harmless because IG pads content for its own bar). Pin it in `LayoutTests.testValuesMatchSpec`, and add
  `testWebNavCoverHidesInstagramNav`: `XCTAssertGreaterThanOrEqual(Metrics.webNavCover, 50)`.
- New `Sources/App/Web/WebNavCover.swift`:
  ```swift
  /// Covers Instagram's own bottom navigation bar (home/search/reels/profile), which this app replaces and which
  /// our CSS cannot hide on every page. Opaque in IG's own background colour and swallows taps so the buttons
  /// under it are neither visible nor reachable.
  struct WebNavCover: ViewModifier {
      func body(content: Content) -> some View {
          content.overlay(alignment: .bottom) {
              Theme.bg
                  .frame(height: Metrics.webNavCover)
                  .contentShape(Rectangle())
                  .onTapGesture {}
                  .accessibilityHidden(true)
          }
      }
  }
  extension View { func coversInstagramNav() -> some View { modifier(WebNavCover()) } }
  ```
- Apply `.coversInstagramNav()` to the `WebSurface()` in `FindPeopleView` and in the new `YouView`. Not Messages
  (the inbox's nav is already hidden by CSS and the composer sits at the bottom there).

## Task 5 — Tabs: Messages · Find people · You · Settings
- `AppTab`: add `case settings` (title "Settings", systemImage "gearshape"); doc comment "the only four destinations".
  Order: messages, findPeople, you, settings.
- `RootView.screen`: `.settings: SettingsView()`.
- `LayoutTests`: add `testFourTabsFitOnSmallestPhone`: `(375 - 2*Metrics.tabBarSide) / 4 >= 72` (enough for "Find
  people" at 10pt). Don't change existing pinned values.

## Task 6 — New `YouView` (my profile) and `SettingsView`
- `Sources/App/You/YouView.swift` (rewrite), modelled on `FindPeopleView`:
  - signed out → `Theme.bg`.
  - `ownUsername != nil` → `VStack(spacing:0) { Text("You") header exactly like Find people; WebSurface().coversInstagramNav() }`
    with `.onAppear { surface.show(.ownProfile, reload: true) }` (reload: after browsing to another profile the
    surface value is unchanged, same reason as Find people) and `.onChange(of: surface.ownUsername)` → show again.
  - `ownUsername == nil` → native fallback: header "You", text (Theme.preview/text2) "Open Messages once so Killagram
    can find your profile, or type your username:", a `TextField("username")` styled like the app's controls
    (height `Metrics.inputControl`, `Radius.field`, fill `Theme.card`, `.textInputAutocapitalization(.never)`,
    `.autocorrectionDisabled()`), and a `GoldCapsuleButtonStyle` "Open profile" button calling `setOwnUsername`;
    on `false` show "That isn't a valid Instagram username." in Theme.label/text3.
- `Sources/App/Settings/SettingsView.swift` (new; move what's left of the old You screen): `ScrollView` with
  title "Settings" (largeTitle) and sections:
  - **Profile**: `ValueRow("Username", "@name" or "Not detected")` + a "Change username" button that reveals the same
    TextField + save (uses `setOwnUsername`).
  - **Diagnostics**: the existing rows unchanged.
  - **Account**: the existing Reset button + confirmation dialog unchanged.
  - Keep `.task { await session.refreshAuthState() }`.
- `RootView.onChange(of: tab)`: keep messages→`show(.messages)`, others→`silence()`.
- Add `Sources/App/Settings` to `project.yml` only if sources are listed per folder (check; XcodeGen usually takes
  `Sources/App` recursively).

## Task 7 — Docs + verify
- `docs/IPHONE_INSTALL.md`: add "## 5. Milestone 4 device checklist": (1) app background is IG's dark navy, no
  colour seam between our title bars and Instagram's pages; (2) Find people: no Instagram bottom buttons visible or
  tappable; (3) open Messages once, then You → your own profile (no story button anywhere); (4) Settings tab shows
  your @username, Diagnostics and Reset; (5) after Reset + login, You re-detects. Mark §4 story-posting step obsolete.
- `NEXT_SESSION_HANDOFF.md`: M4 state + fragile items (username detector depends on IG nav markup on /direct/; cover
  height 56).
- Run `swift test` (WSL command in the M1 plan, "How to run things") — all green before each commit.
- Commit per task, push the branch, confirm the GitHub Actions run is green.
