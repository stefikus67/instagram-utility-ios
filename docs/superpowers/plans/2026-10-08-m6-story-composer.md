# M6 — Post a story from Killagram (composer mode)

Planned 2026-10-08 on Opus. Build in a cloud session (Sonnet), branch `m6-story-composer` from `main`.

## Facts
- Owner (verified on his iPhone, Safari, instagram.com mobile site): the **+ (New post / New story)** button is on the
  **home feed's top bar**, left of the notifications heart; a **"Your story"** button is also in the stories row. Both
  live on the home page `/`, which Killagram blocks everywhere.
- Instagram labels the + icon `svg[aria-label="New post"]` (verified on the desktop site 2026-10-08; labels are shared
  across layouts — device-verify). On mobile its menu offers Post and Story.
- M3 tried loading `/create/story/` directly: with a mobile UA Instagram redirects it to `/`, so that never worked. The
  composer must be reached through Instagram's own button (in-app SPA navigation), not a direct URL load.
- No desktop user agent (rejected by owner; also removed in M4). Mobile UA only.

## Design
A "Post story" button on the You tab opens a full-screen **composer mode**: the shared web view loads Instagram's home
page `/` with its feed hidden, Killagram taps Instagram's own + for the user, the user picks **Story** and posts in
Instagram's own composer, and when done the cover closes and the app returns to Messages.

### 1. Route policy (pure, tested) — `Sources/RoutePolicy/InstagramRoutePolicy.swift`
- Add `static let homeURL = URL(string: "https://www.instagram.com/")!` and `static func isHome(_ url: URL) -> Bool`
  (Instagram host, zero path segments; query ignored). Tests: `/` and `/?hl=en` true; `/direct/inbox/`, `/explore/`,
  non-Instagram host false. **`classify` is unchanged** — home stays `.blocked` by policy; only composer mode overrides.

### 2. NavigationGuard — composer override
- `var composerMode = false` (set by the controller). A private `category(for url:)` returns `.createAllowed` when
  `composerMode && InstagramRoutePolicy.isHome(url)`, otherwise `InstagramRoutePolicy.classify(url, from: lastAllowedURL)`.
  Use it everywhere classify is used now (decidePolicyFor, handleObservedURL, handleBlockedPath, createWebViewWith).
- Track `composerVisitedCreate` (true once an allowed URL whose first segment is `create` was recorded while in composer
  mode). Expose `var onComposerFinished: () -> Void`, fired once when, in composer mode with `composerVisitedCreate`
  true, the observed/committed URL becomes home, `/direct/...` or a profile (Instagram goes back there after posting).
- `reset()` also clears composer state.

### 3. Injected JS — `InjectedScripts.composerJS` (document-end, add to `documentEnd()`)
Exposes `window.__iuStartComposer()`; does nothing until called. When called:
- sets `data-iu-composer` on `<html>` (CSS below hides the feed);
- finds the + by `svg[aria-label="New post"]` → `closest('a,[role="button"],button')` and calls `.click()` once; if not
  present yet, a debounced (≥100 ms) MutationObserver retries; gives up after 10 s (one `setTimeout`, no polling);
- posts `'opened'` or `'notfound'` to a new `iuComposer` message handler;
- removes `data-iu-composer` when the path is no longer `/` (history hooks + popstate, like the other scripts).
CSS additions in `hideChromeCSS` (hide-only):
`html[data-iu-composer] main article { visibility:hidden !important; }` and
`html[data-iu-composer] main [role="feed"] { visibility:hidden !important; }` — the top bar (+), the stories row ("Your
story") and Instagram's menus/dialogs stay visible.
Guardrail tests: add `composerJS` to every existing list (IIFE/try/catch, banned strings, no setInterval); new test: it
contains `New post`, `iuComposer`, `data-iu-composer`, `MutationObserver`, and no `fetch(`/`cookie`/`localStorage`.

### 4. WebSurfaceController
- `Surface.composer` → `InstagramRoutePolicy.homeURL`.
- `func startComposer()`: `navigationGuard.composerMode = true`, `show(.composer, reload: true)`.
  After every page finish while composer mode is on, evaluate `window.__iuStartComposer && window.__iuStartComposer()`.
- `func endComposer()`: composer mode off, `silence()`, `show(.messages, reload: true)`.
- `@Published private(set) var composerHint: String?`: `nil` normally; on `'notfound'` → "Tap + at the top, then Story.".
- Register the `iuComposer` handler (main frame only, weak target — same pattern as `OwnUsernameBridge`).
- `navigationGuard.onComposerFinished` → publish `composerFinished` (e.g. a `@Published var composerOpen: Bool` that the
  view binds to) so the cover closes.

### 5. UI — `Sources/App/You/YouView.swift`
- In the You header row (only when the profile is shown): a trailing `IconButton(systemImage: "plus")` labelled
  "Post story" (accessibilityLabel). Tap → `surface.startComposer()` + present `.fullScreenCover`.
- Cover content: `ZStack(alignment: .topTrailing) { Theme.bg.ignoresSafeArea(); WebSurface(); IconButton("xmark") }`,
  plus a bottom `Text(composerHint)` capsule (Theme.label on Theme.raise) when the hint is set. No nav cover in this mode.
- Dismiss (X or `composerFinished`) → `surface.endComposer()`.
- Also restore `RootView.loginRequired` suppression while the cover is up (login sheet must not stack on it) —
  reintroduce a `@Published var isPresentedFullScreen` on the controller, set by start/endComposer.

### 6. Docs
- `docs/IPHONE_INSTALL.md` §6 "Milestone 6 device checklist": (1) You → + → Instagram's home opens with **no feed
  visible** and its New post/Story menu opens by itself (or the hint shows; tap + yourself); (2) pick Story → composer
  opens (not bounced to Messages/Find people); (3) pick a photo, add text, share → the cover closes and Messages shows;
  (4) X closes at any point and the feed is never reachable (Home/Reels taps bounce); (5) Diagnostics "Blocked
  navigations" still counts feed attempts outside composer mode.
- `NEXT_SESSION_HANDOFF.md` + `AGENTS.md`: story posting is back via composer mode (home allowed ONLY while the composer
  cover is open; feed hidden by CSS; + clicked via its aria-label). Fragile: `aria-label="New post"`, feed selectors.

### Process
- Run `swift test` (Linux toolchain if available in the cloud box; otherwise rely on CI) before each commit; CI
  (`build-ios.yml`) must be green — it is the only real compile of `Sources/App`. Be careful with exhaustive switches
  over `Surface`, `RouteCategory`, `AppTab`; iOS 16 APIs only; `.onChange(of:) { newValue in }` form.
- Commits end with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. Push, open a PR to `main`
  ("M6: post a story via composer mode", body ends with the Claude Code attribution line), do not merge.
