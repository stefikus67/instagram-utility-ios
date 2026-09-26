# Instagram Utility (iOS proof of concept)

A minimal SwiftUI iPhone app that shows Instagram **Direct Messages only**, inside a WKWebView using your own
genuine Instagram Web login, behind a default-deny navigation firewall (no Home, Explore or Reels).

Status: POC. Code + CI are written; **nothing has been run on a real iPhone or against a real Instagram account yet.**

## How it works
SwiftUI shell → one persistent `WKWebView` (real Instagram login, session stays on device) →
`InstagramRoutePolicy` classifies every URL (`AUTH_ALLOWED`, `DIRECT_ALLOWED`, `DM_MEDIA_ALLOWED_ONCE`, `BLOCKED`, `EXTERNAL`).

## Build (no Mac needed)
Push to GitHub → Actions builds on `macos-latest` → download `InstagramUtility-unsigned.ipa` from the run's artifacts
→ sign/install with SideStore. See [docs/IPHONE_INSTALL.md](docs/IPHONE_INSTALL.md).

## Test
```
swift test
```
Tests cover the route policy only (no Instagram account needed). They do not prove login or messaging works.

## For contributors / agents
Read [AGENTS.md](AGENTS.md).
