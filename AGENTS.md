# AGENTS.md — Killagram (iOS)

Read this, then the spec: `docs/superpowers/specs/2026-10-05-instagram-utility-v1-design.md` (§A for the website-based pivot).

## Product
**Killagram:** a fast native iPhone app for Instagram communication: DMs, stories, story posting, finding people.
**No feed, Explore or Reels — the code for them must not exist.** Content is only ever shown from a
profile the user deliberately opened or something someone sent them.

**Architecture (Milestone 3 onwards):** Instagram's own mobile website inside `WKWebView`, made into a focused product by controlling navigation and presentation. Three native tabs (Messages · Find people · You) each drive the web surface. Search on Find people uses Instagram's own /explore/search/ page for real account suggestions; that is the only Explore sub-route allowed. Story posting works by switching to a desktop user agent (Version/17.0 string) ONLY while the /create/story/ page is open, reverting to mobile everywhere else.

## Hard rules
1. €0. No paid Apple program, server, hosting, CI or dependency.
2. No backend. The app works alone on the phone.
3. Never handle the password. Login is Instagram's own page in `InstagramSession`'s web view.
4. Never log, display or commit cookies, session ids, tokens or user data. Fixtures use fake names.
5. Every colour/size in native views comes from `Theme` / `Spacing` / `Metrics` / `Radius` / `TypeScale`.
   No raw numbers or hex in views. Token tests fail the build if the system drifts.
6. **Injected JS safety (enforced by guardrail test):** Injected JavaScript may only hide/navigate/scroll/set CSS classes/override `screen.orientation`. Never read cookies/tokens, never fetch/XHR, never access IG's data structures. Injected JS is defensive and device-verified only; behaviour is not CI-tested.

## Where things go
| Concern | Location |
|---|---|
| Colours, spacing, type, radii, sizes (+ tests) | `Sources/DesignTokens/`, `Tests/DesignTokensTests/` |
| Content blocker rules & injected scripts (+ tests) | `Sources/WebAssets/`, `Tests/WebAssetsTests/` |
| Route firewall & navigation guard | `Sources/App/Web/` (WebSurfaceController, NavigationGuard, InstagramWebView, WebSurface) |
| SwiftUI components | `Sources/App/DesignSystem/` |
| Native screens | `Sources/App/Messages/`, `Sources/App/FindPeople/`, `Sources/App/You/` |
| Login / session web view | `Sources/App/Session/InstagramSession.swift` |
| App shell and tabs | `Sources/App/App/RootView.swift`, `DesignSystem/PillTabBar.swift` |

**Techniques** (spec §A):
- **Route firewall** (NavigationGuard): blocks feed/Explore (except /explore/search/)/Reels/cross-content "next"; allows profiles, search, stories, story creation.
- **Content rule list** (`WKContentRuleList`): blocks feed/Explore/Reels/ads/tracker requests at the network layer (hard firewall, main speed win).
- **Injected CSS/JS**: hides Instagram's nav chrome; locks DM-opened reels so they can't scroll to the next; overrides `screen.orientation` for story posting; unread-only inbox toggle (detects Instagram's unread-blue dot).
- **Desktop user agent for story posting:** switches to desktop UA (Version/17.0 string) ONLY on /create/story/, reverts to mobile everywhere else — works around Instagram's mobile web block on the composer.

**Confirmed web limits** (permanent, not fixable in a web wrapper): view-once ("tap to view") DM photos/videos are app-only on every Instagram web surface; live in-app camera capture in DMs is app-only (camera-roll send still works).

## Build & test
- `swift test` runs every pure-logic test (Linux or macOS). Locally on Windows use the WSL command in `docs/superpowers/plans/2026-10-05-m1-foundation.md` ("How to run things").
- The iOS app builds only in CI (`.github/workflows/build-ios.yml`): `swift test` → XcodeGen → unsigned Release build → `InstagramUtility-unsigned.ipa` artifact. Install with SideStore (`docs/IPHONE_INSTALL.md`).
- SwiftUI native screens have no unit tests. **Injected JS behaviour is device-verified only** (Milestone 2 device checklist, not CI-verified). CI verifies: design tokens, content rules grammar, guardrail tests (JS safety).

## Current state
Milestone 3 (Killagram, M3) shipped. Device checklist (`docs/IPHONE_INSTALL.md` §4) is the acceptance gate.
