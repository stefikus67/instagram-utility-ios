# AGENTS.md — Instagram Utility (iOS)

Read this, then the spec: `docs/superpowers/specs/2026-10-05-instagram-utility-v1-design.md`.

## Product
A fast native iPhone app for Instagram communication: DMs, stories, story posting, finding people.
**No feed, Explore or Reels — the code for them must not exist.** Content is only ever shown from a
profile the user deliberately opened or something someone sent them.

## Hard rules
1. €0. No paid Apple program, server, hosting, CI or dependency.
2. No backend. The app works alone on the phone.
3. Data comes from the internal endpoints instagram.com itself uses, called from the user's own session
   on the phone (spec §2). Never imitate the official app's device signatures. Respect the request
   budget in spec §5.
4. Never handle the password. Login is Instagram's own page in `InstagramSession`'s web view.
5. Never log, display or commit cookies, session ids, tokens or user data. Fixtures use fake names.
6. Every colour/size in views comes from `Theme` / `Spacing` / `Metrics` / `Radius` / `TypeScale`.
   No raw numbers or hex in views. Token tests fail the build if the system drifts.

## Where things go
| Concern | Location |
|---|---|
| Colours, spacing, type, radii, sizes (+ tests) | `Sources/DesignTokens/`, `Tests/DesignTokensTests/` |
| Injected web content rules and scripts (+ tests) | `Sources/WebAssets/`, `Tests/WebAssetsTests/` |
| Web-chat route firewall | `Sources/RoutePolicy/`, `Tests/RoutePolicyTests/` |
| SwiftUI components | `Sources/App/DesignSystem/` |
| Screens | `Sources/App/<Feature>/` (FindPeople, You, WebChat, Session) |
| Login / session web view | `Sources/App/Session/InstagramSession.swift` |
| App shell and tabs | `Sources/App/App/RootView.swift`, `DesignSystem/PillTabBar.swift` |

## Build & test
- `swift test` runs every pure-logic test (Linux or macOS). Locally on this Windows machine use the WSL
  command in `docs/superpowers/plans/2026-10-05-m1-foundation.md` ("How to run things").
- The iOS app builds only in CI (`.github/workflows/build-ios.yml`): `swift test` → XcodeGen → unsigned
  Release build → `InstagramUtility-unsigned.ipa` artifact. Install with SideStore (`docs/IPHONE_INSTALL.md`).
- SwiftUI views have no unit tests; each milestone ends with the owner's on-device checklist.

## Current state
Milestone 1 (foundation). Inbox shows sample data only; the live inbox and native chat come next,
after the endpoint-discovery session. Chats open in web chat for now.
