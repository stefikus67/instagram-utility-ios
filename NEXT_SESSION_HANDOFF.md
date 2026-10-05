# Handoff — Instagram Utility

## State (2026-10-06 — M2 shipped)
**Milestone 2 (website product)** shipped per `docs/superpowers/plans/2026-10-06-m2-website-product.md`.
- Architecture: Instagram's mobile website in WKWebView, made focused by: expanded route firewall (profiles/stories/create allowed; feed/explore/reels blocked), content rule list blocking feed/explore/reels/ads at network layer, injected CSS/JS (hide IG nav, lock reel scroll in DMs, screen.orientation override, unread-only inbox toggle).
- Three native tabs: Messages (web inbox), Find people (native username field), You (Post story, Diagnostics, Reset).
- Dead M1 native-inbox code removed. Web-chat concept removed (Messages IS the web inbox now).
- **Device checklist** (`docs/IPHONE_INSTALL.md` §4): the acceptance gate — 9 steps, 6 of which involve injected JS (steps 1, 2, 4, 6, 7, 8). Owner to run and report.
- **CI acceptance:** run 37352237383, artifact `InstagramUtility-unsigned-ipa` (184,540 bytes / ~0.18 MB). Unit tests passed; build successful.

## Known-fragile items to re-verify after Instagram site changes
Injected-JS selectors that are likely to break if Instagram's markup changes:
- IG bottom nav: `div[role=menubar]` (hide injection)
- Inbox unread marker: selector TBD pending implementation
- Next-reel affordance: selector TBD pending implementation  
- Reel-pager scroll-snap: selector TBD pending implementation
- Logged-out "/" redirect: verify no infinite loop if "/" redirects when logged out
- Story-cover composer overlap/file-picker: verify no overlap and file input works

**Content-rule GraphQL identifier:** must be bumped whenever rules change (current: TBD pending CI run).

## Deferred minors from per-task reviews (revisit if time permits)
- Profile deny-list (block repeated navigation to same profile).
- Fail-open content rules (currently fail-closed; add no-op fallback if rule matching fails).
- Cache keyed by identifier not hash (simpler invalidation).
- Unread toggle visible inside conversations (toggle currently inbox-only).
- Flash-of-chrome at document-end (brief flicker of IG nav before JS hides it).
