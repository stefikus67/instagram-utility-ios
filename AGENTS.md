# AGENTS.md — Instagram Utility (iOS)

Read this before changing anything.

## Product philosophy
Instagram as a **communication protocol**, not a content-consumption environment. This is our own app
whose UI simply has no Home feed, Explore or Reels — not Instagram with buttons hidden.
**Capability does not exist > capability exists but is hidden.** Never solve an attention requirement with CSS only.

## Hard rules
1. **Zero cost.** No paid Apple Developer Program, signing service, server, hosting, CI or dependency.
2. **No backend.** The app must work standalone on the phone. No always-on PC, no cloud.
3. **No private Instagram API** (no instagrapi/aiograpi, no faked mobile signatures). Genuine Instagram Web in a WKWebView only.
4. **Never handle credentials.** Login happens on Instagram's own page. No password variables, no credential interception.
5. **Never log/display/commit** cookies, session ids, tokens, Apple/signing material, user data.
   (Cookie *names* may be checked for auth state; values are never stored or shown.)
6. No high-volume/automated Instagram activity. Behave like a human using Instagram Web.
7. Do not add feed/Explore/Reels/discovery surfaces, even "temporarily". Default-deny in the route policy.

## Architecture (where things go)
| Concern | File |
|---|---|
| Navigation firewall (pure logic, unit-tested) | `Sources/RoutePolicy/InstagramRoutePolicy.swift` |
| Firewall enforcement on the web view (delegate + URL KVO for SPA routes) | `Sources/App/Web/NavigationGuard.swift` |
| WKWebView, persistent session, auth state, reset | `Sources/App/Web/InstagramSession.swift` |
| SwiftUI wrapper for the web view | `Sources/App/Web/InstagramWebView.swift` |
| App shell / tabs / Messages screen | `Sources/App/App/` |
| Settings + Reset Session | `Sources/App/Settings/SettingsView.swift` |
| Diagnostics state | `Sources/App/Diagnostics/DiagnosticsStore.swift` |
| Tests | `Tests/RoutePolicyTests/` |
| Project definition | `project.yml` (XcodeGen; `.xcodeproj` is generated, never committed) |

Boundaries: `Sources/RoutePolicy` imports Foundation only (no UIKit/WebKit) so `swift test` runs anywhere.
Route rules change there first, with tests, before any UI work. Example: "add an unread-only toggle to
Messages" → `Sources/App/App/MessagesView.swift` (and, once native inbox exists, a new folder under `Sources/App/`).

## Build & test
- Development can happen on Windows; **iOS builds only happen in CI** (`.github/workflows/build-ios.yml`, `macos-latest`).
- Logic tests: `swift test` (needs a Swift toolchain; runs in CI on every push).
- CI: `swift test` → `brew install xcodegen` → `xcodegen generate` → `xcodebuild` Release, `generic/platform=iOS`,
  `CODE_SIGNING_ALLOWED=NO` → wrap `.app` in `Payload/` → zip to `InstagramUtility-unsigned.ipa` → upload artifact.
- Install on device: `docs/IPHONE_INSTALL.md` (SideStore, free Apple ID, 7-day refresh).

## Firewall notes
- Instagram is an SPA: most route changes are `pushState`, not WK navigations. `NavigationGuard` observes `webView.url`
  and hard-redirects from blocked routes to the last allowed `/direct/` page.
- DM media (`/p/…`, `/reel/…`) is allowed only when the previous allowed route was `/direct/…`. From media, any other media
  route is blocked (no reel chains). Query-only changes on the same media page are allowed.
- Login lands on `/` sometimes; `/` is blocked and redirects to the inbox. That is intended.

## Intentionally absent (do not add without being asked)
Home/Explore/Reels, Stories, posting, account search, profiles, followers/following, native inbox/chat,
push notifications, backend, AI features, automation, multiple accounts, analytics.
