# Killagram (iOS)

A fast native iPhone app for Instagram communication — messages, stories, finding people — with no feed,
Explore or Reels. Your genuine Instagram login stays on the phone; there is no backend.

Status: **Milestone 3 shipped.** Gold-camera icon, search via Instagram's own /explore/search/ page, desktop UA for story posting, unread-only toggle.
Spec: `docs/superpowers/specs/2026-10-05-instagram-utility-v1-design.md`.

## How it works
Instagram's own mobile website in `WKWebView`, made into a focused product by: expanded route firewall
(profiles/stories/create/explore-search allowed; feed/explore/reels blocked), a content rule list blocking feed/explore/reels/ads
requests at the network layer, and injected CSS/JS (hide IG nav chrome, lock reel scroll in DMs, override
screen.orientation for story posting, unread-only inbox toggle). Find people uses Instagram's own search page for real account suggestions.
Story posting switches to desktop user agent (works around mobile web block) then reverts to mobile. Three native tabs: Messages (web inbox),
Find people (Instagram search), You (Post story / Diagnostics / Reset). No backend.

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
