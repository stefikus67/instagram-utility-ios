# Instagram Utility (iOS)

A fast native iPhone app for Instagram communication — messages, stories, finding people — with no feed,
Explore or Reels. Your genuine Instagram login stays on the phone; there is no backend.

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
Tests cover the design tokens (contrast and proportions), the core inbox logic and the web-chat route firewall. They need no Instagram account and do not prove login or messaging works.

## For contributors / agents
Read [AGENTS.md](AGENTS.md).
