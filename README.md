# Instagram Utility (iOS proof of concept)

A minimal SwiftUI iPhone app that shows Instagram **Direct Messages only**, inside a WKWebView using your own
genuine Instagram Web login, behind a default-deny navigation firewall (no Home, Explore or Reels).

Status: v1 in progress — milestone 1 (foundation: design system, login, three-tab shell, cache-first
inbox with sample data, web chat fallback). Live inbox and native chat are next.
Spec: `docs/superpowers/specs/2026-10-05-instagram-utility-v1-design.md`.

## How it works
Native SwiftUI screens styled by one token system (Espresso v3). A hidden persistent `WKWebView` holds
your genuine Instagram login on the device. Web chat (Instagram's own page, behind a route firewall)
is the fallback. No backend.

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
