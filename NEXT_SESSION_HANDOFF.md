# Handoff — Killagram (Instagram Utility)

## M6 (2026-10-08): story posting is back via composer mode (branch `m6-story-composer`, device-unverified)
Plan: `docs/superpowers/plans/2026-10-08-m6-story-composer.md`. Device checklist: `docs/IPHONE_INSTALL.md` §6.
- You tab → **+** opens a full-screen cover. Instagram's home page `/` is allowed **only while that cover is open**
  (`NavigationGuard.composerMode`; `InstagramRoutePolicy.classify` still says home is blocked). The feed is hidden by CSS
  (`html[data-iu-composer] main article / [role="feed"]`); `InjectedScripts.composerJS` taps Instagram's own **New post** (+)
  button once; the user picks Story and posts in Instagram's own UI. The cover closes when Instagram returns to home/inbox/a
  profile after a `/create/` page, or via the X. `Settings`/tabs untouched.
- **Fragile:** `svg[aria-label="New post"]` (the + lookup), the feed selectors (`main article`, `main [role="feed"]`), and the
  assumption that Instagram visits a `/create/...` URL (needed for the auto-close; the X always works).

## M5 (2026-10-07): own-account pages allowed (edit profile, settings /accounts/*, /archive/, /your_activity/; logout + signup stay blocked); unread-only toggle removed (owner: did not work on device, not needed). M4 device-tested OK and merged to main (username had to be typed — auto-detect missed; owner fine with that).

## State (2026-10-07 — M4 implemented on branch `m4-profile-settings`, not merged, device-unverified)
**M4 CI green:** run 37608770201, artifact `InstagramUtility-unsigned-ipa` (257,812 bytes): https://github.com/stefikus67/instagram-utility-ios/actions/runs/37608770201
Plan: `docs/superpowers/plans/2026-10-07-m4-profile-settings-palette.md`. Device checklist: `docs/IPHONE_INSTALL.md` §5.
- **Palette** matches Instagram's dark web theme (bg #0C1014, card #212328, raise #25292E); gold stays the accent.
- **Story posting removed** (app layer). `InstagramRoutePolicy` create-story rules and `orientationFixJS` are kept, unused by the UI.
- **You tab = own profile.** The username is auto-detected by `InjectedScripts.ownProfileJS` (inbox only, posts to `iuOwnUsername`),
  persisted in UserDefaults, with a typed-in fallback. Reset clears it.
- **Settings is a fourth tab** (gear): Profile (username, change), Diagnostics, Reset.
- **Find people / You** cover Instagram's bottom nav with an opaque strip (`Metrics.webNavCover` = 56).
- **New fragile items:** the username detector depends on Instagram's nav markup on /direct/ (links inside `[role=menubar]`/`nav`);
  the nav cover height (56) may need tuning on device. Both are device-verified only. Needs CI green + device check before merging to main.

## State (2026-10-06 — M3 shipped)
**Milestone 3 (Killagram)** shipped with the following enhancements:
- **Renamed to Killagram** with new gold-camera icon.
- **Find people search:** now uses Instagram's own /explore/search/ page for real account suggestions as you type; /explore/search/ is the only allowed Explore sub-route.
- **Story posting:** switches to desktop user agent (Version/17.0 string) ONLY while /create/story/ is open, reverts to mobile everywhere else — works around Instagram's mobile web block.
- **Confirmed web limits (permanent, not fixable in web wrapper):** view-once ("tap to view") DM photos/videos are app-only on every Instagram web surface; live in-app camera capture in DMs is app-only (camera-roll send still works).
- Architecture: Instagram's mobile website in WKWebView, made focused by: expanded route firewall (profiles/stories/create/explore-search allowed; feed/explore/reels blocked), content rule list blocking feed/explore/reels/ads at network layer, injected CSS/JS (hide IG nav, lock reel scroll in DMs, screen.orientation override, unread-only inbox toggle).
- Three native tabs: Messages (web inbox), Find people (Instagram search), You (Post story, Diagnostics, Reset).
- **Device checklist** (`docs/IPHONE_INSTALL.md` §4): the acceptance gate — 8 steps. Owner to run and report.
- **CI acceptance (merged to main):** run 37382121421, artifact `InstagramUtility-unsigned-ipa` (242,912 bytes). 69 tests pass; build+IPA successful. Download: https://github.com/stefikus67/instagram-utility-ios/actions/runs/37382121421

## Known-fragile items to re-verify after Instagram site changes
Injected-JS selectors that are likely to break if Instagram's markup changes:
- IG bottom nav: `div[role=menubar]` (hide injection)
- Reel-scroll lock in DMs: scroll-snap or scroll-behavior CSS rules — may change if Instagram's layout changes
- Story composer page: `/create/story/` URL — depends on Instagram's routing staying stable
- Desktop UA Version string: currently Version/17.0 — may need update if Instagram changes detection
- currentSurface quirk: returning to Find people may show the last viewed profile instead of search — depends on Instagram's page state management

**Content-rule GraphQL identifier:** must be bumped whenever rules change.

## Deferred minors from per-task reviews (revisit if time permits)
- Profile deny-list (block repeated navigation to same profile).
- Fail-open content rules (currently fail-closed; add no-op fallback if rule matching fails).
- Cache keyed by identifier not hash (simpler invalidation).
- Flash-of-chrome at document-end (brief flicker of IG nav before JS hides it).

## M3 device-check priorities (the real go/no-go — CI can't verify these)
1. **Renamed to Killagram:** icon + app name visible on home screen (checklist 1).
2. **Search via Instagram's /explore/search/:** type works, suggestions appear, tap opens profile (checklist 4). /explore/search/ is the only allowed Explore sub-route — confirm other /explore/ paths bounce back.
4. **Story posting via desktop UA:** compose page opens (not the inbox), photo picker works, posting succeeds without "rotate your device" block (checklist 7). After posting, you return to Messages.
5. **Reel scroll-lock in DMs (checklist 5):** a reel must not scroll to the next; but a reel's comments / a post's caption must still scroll. Both behaviours need injected JS working correctly.
6. **App-only limits are real (not bugs):** view-once DM photos won't open; in-DM live camera is unavailable (camera roll send works). Report if you find a workaround (unlikely).
