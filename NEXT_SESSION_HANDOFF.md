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

## M2 final-review device-check priorities (the real go/no-go — CI can't verify these)
1. Logged-out redirect must NOT loop: at login / after Reset, confirm you land on the login page and it stays (checklist 1/9). The native KVO redirect path isn't signed-out-guarded; it should terminate at /accounts/login/ but verify.
2. Reel scroll-lock (checklist 4): a DM-opened reel must not scroll to the next; but a reel's comments / a post's caption MUST still scroll.
3. Same-person post swiping (checklist 5): opening a post from a profile works, but swiping grid→next post currently bounces back to the profile (media→media is blocked unless same route). Spec wanted same-person swiping — decide if that gap matters; relaxing it safely would need a policy tweak.
4. Injected-JS selectors (checklist 1,2,6,7,8): IG bottom nav `div[role=menubar]`, inbox unread marker, next-reel affordance, reel-pager scroll-snap, orientation fix on /create/story/. Any misbehaviour → report exactly what you saw; usually a one-line selector tweak.
5. Content-rule path `/api/v1/web/launcher/sync` — confirm no app-config side effect; and `ig-firewall-v1` identifier must be bumped whenever ContentRules change (stale compiled cache otherwise).
