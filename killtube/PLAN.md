# Killtube — Shorts-free YouTube in iPhone Safari (userscript)

Owner: Stepan. Personal productivity tool (not a product). Planned 2026-10-08 on Opus; build in a cloud session.

## Goal
YouTube on the iPhone without Shorts and without rabbit holes, keeping everything Stepan pays for (YouTube Premium) and
uses (login, playlists, Watch later, history, comments, screen-off audio). He deletes the YouTube app; YouTube runs in
**Safari** with the free **Userscripts** app (quoid/userscripts, App Store) running `killtube.user.js`.

Why Safari + userscript instead of a wrapper app like Killagram: Google blocks sign-in inside embedded web views and we
do not work around that; Safari keeps real Google login + Premium, can resume audio from the lock screen, and uses no
SideStore slot.

## Owner decisions
- Start screen = **search only** (no home feed, no subscriptions feed, no trending/explore).
- **Up next / related videos hidden**, autoplay-to-next stopped. Comments stay.
- **No Shorts anywhere.** A `/shorts/<id>` link (e.g. sent by a friend) opens as a normal single video
  (`/watch?v=<id>`) — one video, no swipe feed. Channel Shorts tabs hidden; `/@x/shorts` → `/@x/videos`.
- Keep: login, `/feed/library`, `/feed/you`, `/feed/playlists`, `/feed/history`, `/playlist?list=`, `/watch`,
  `/results`, channel pages (`/@x`, `/channel/...`, `/c/...`, `/user/...`) minus their Shorts tab, comments, account pages.
- Screen-off audio: best effort (see §4); documented fallback = press play on the lock-screen player.

## DOM facts (measured 2026-10-08 on m.youtube.com, Android-UA mobile emulation, logged out)
- App shell custom elements: `ytm-app`, bottom nav `ytm-pivot-bar-renderer` with items `ytm-pivot-bar-item-renderer`
  (Home, Shorts, You — match the Shorts item by its text/aria label "Shorts", there is no stable class).
- Search results: Shorts come as `grid-shelf-view-model` rows containing `ytm-shorts-lockup-view-model`
  (links `a.reel-item-endpoint[href^="/shorts/"]`). Normal results: `ytm-video-with-context-renderer`.
- Watch page: `ytm-watch`, `ytm-single-column-watch-next-results-renderer`; related videos are
  `ytm-item-section-renderer[section-identifier="related-items"]`; comments are a separate
  `comments-entry-point-teaser-view-model` (must stay visible).
- Home: `ytm-browse` with `ytm-rich-grid-renderer` (the feed to hide).
- Also handle desktop/iPad YouTube (www.youtube.com, `ytd-*`): `ytd-reel-shelf-renderer`,
  `ytd-rich-shelf-renderer[is-shorts]`, `ytd-rich-section-renderer:has(ytd-rich-shelf-renderer[is-shorts])`,
  guide/mini-guide entries titled "Shorts", `yt-chip-cloud-chip-renderer` whose text is "Shorts", `#related`,
  `ytd-watch-next-secondary-results-renderer`, home `ytd-browse[page-subtype="home"] #contents`.
- Selectors are best-effort; everything must degrade to "nothing happens", never break the page.

## Deliverables (all under `killtube/`)
1. `killtube.user.js` — the userscript.
2. `test/killtube.test.js` — Node tests (built-in `node:test`, no dependencies; `jsdom` allowed as a devDependency only if
   really needed).
3. `package.json` (private, `"test": "node --test"`), `README.md` (iPhone install guide, §6).
4. `.github/workflows/killtube.yml` — runs `node --test` in `killtube/` on ubuntu-latest for pushes touching `killtube/**`.
   Do **not** touch `.github/workflows/build-ios.yml` or anything outside `killtube/` + that new workflow file.

## 1. Script structure
```
// ==UserScript==
// @name         Killtube
// @description  Shorts-free, search-only YouTube. No Up next, no autoplay chains.
// @version      1.0.0
// @match        *://m.youtube.com/*
// @match        *://www.youtube.com/*
// @match        *://youtube.com/*
// @run-at       document-start
// @inject-into  page
// @grant        none
// ==/UserScript==
```
- One IIFE wrapped in try/catch. A pure core exported for tests:
  `if (typeof module !== 'undefined' && module.exports) module.exports = { decide, CSS, ... }`, and the DOM/side-effect
  part only runs when `typeof window !== 'undefined' && window.location && /youtube\.com$/.test(location.hostname)`.
- **`decide(pathname, search)` → `{ action: 'allow' } | { action: 'redirect', to: '<path+query>' } | { action: 'home' }`**
  (pure, unit-tested):
  - `/shorts/<id>` → redirect `/watch?v=<id>`; `/shorts` or `/shorts/` → home.
  - `/@x/shorts`, `/channel/<id>/shorts`, `/c/x/shorts`, `/user/x/shorts` → redirect same base + `/videos`.
  - `/feed/subscriptions`, `/feed/trending`, `/feed/explore`, `/gaming`, `/feed/storefront`, `/hashtag/...` → home.
  - `/` → `{action:'home'}` (rendered as search-only, not a redirect).
  - everything else → allow.
  Constant `BLOCK_SUBSCRIPTIONS_FEED = true` at the top so Stepan can flip it.
- **Navigation hooks** (no polling, no `setInterval`): run `apply()` at start, on `yt-navigate-start`,
  `yt-navigate-finish`, `yt-page-data-updated`, `popstate`, and after patched `history.pushState`/`replaceState`.
  Redirects use `location.replace` (no history entry). Guard against loops (never redirect to the same URL).
- **Click capture** (capture phase on `document`): a click on any `a[href^="/shorts/"]` → preventDefault +
  `location.assign('/watch?v=<id>')`.

## 2. Hiding (CSS injected into a `<style id="killtube-css">`, re-appended if YouTube removes it)
- Shorts: `ytm-shorts-lockup-view-model`, `grid-shelf-view-model:has(ytm-shorts-lockup-view-model)`,
  `ytm-reel-shelf-renderer`, `ytm-reel-item-renderer`, `ytm-item-section-renderer:has(> lazy-list > grid-shelf-view-model ytm-shorts-lockup-view-model)`,
  any `a[href^="/shorts/"]`'s nearest item container, plus the desktop `ytd-*` equivalents in DOM facts.
- Shorts nav item + Shorts chips/tabs: CSS cannot match by text, so a small debounced `MutationObserver` marks
  them with `data-killtube-hide` (match trimmed text or aria-label exactly "Shorts"), and CSS hides
  `[data-killtube-hide]`. Same observer marks channel tabs whose link ends in `/shorts`.
- Up next: `ytm-item-section-renderer[section-identifier="related-items"]`, `#related`,
  `ytd-watch-next-secondary-results-renderer`, end-screen cards (`.ytp-endscreen-content`, `.ytp-ce-element`,
  `.ytm-autonav-bar`, `ytm-autonav-endscreen-renderer` if present).
- Home feed: `ytm-browse ytm-rich-grid-renderer`, `ytd-browse[page-subtype="home"] #contents`, and the home's chip bar.
- Never hide: comments (`comments-entry-point-teaser-view-model`, `ytm-comment-section-renderer`, `ytd-comments`),
  player, title/metadata, playlist panels on `/watch?list=`.

## 3. Search-only home
On `{action:'home'}` (path `/`): add `data-killtube-home` on `<html>` (CSS hides the feed) and insert one
`<form id="killtube-search">` (centered, large `<input type="search" placeholder="Search YouTube">`, dark styling that
matches YouTube's dark theme, `autofocus` not forced) that navigates to `/results?search_query=<encoded>`. Remove the
attribute/form when leaving `/`. The YouTube top-bar search icon keeps working too.

## 4. Autoplay + screen-off audio (best effort, device-verified only)
- Autoplay chain: when a `<video>` fires `ended` on `/watch`, record `endedAt` + current URL; if a navigation to a
  different `/watch` starts within 8 s with no user click/tap in between, cancel it by
  `history.back()` once (or `location.replace(previousUrl)`). Also, if a visible autoplay toggle
  (`[aria-label*="utoplay"]` with `aria-pressed="true"` / `aria-checked="true"`) is found on a watch page, click it once
  per page load to turn it off.
- Screen-off audio: at document-start, override `document.hidden` → false, `document.visibilityState` /
  `webkitVisibilityState` → 'visible', `document.webkitHidden` → false (via `Object.defineProperty` on
  `Document.prototype`, configurable), and stop `visibilitychange` / `webkitvisibilitychange` events in the capture phase
  on `document` and `window` (`stopImmediatePropagation`). Do not touch `pagehide`/`blur`. Document in README that the
  fallback is: lock the phone, press play on the lock-screen player.

## 5. Guardrails (enforced by tests that read the script source)
- No `fetch(`, `XMLHttpRequest`, `sendBeacon`, `document.cookie`, `localStorage`, `sessionStorage`, `indexedDB`,
  `setInterval`, `eval(`, `new Function`.
- Everything inside try/catch; all DOM lookups null-guarded; MutationObserver callbacks debounced (≥100 ms).
- Tests: `decide()` table (≥20 cases incl. `/shorts/abc123` → `/watch?v=abc123`, `/shorts/abc?feature=share`,
  `/@veritasium/shorts` → `/@veritasium/videos`, `/watch?v=x` allow, `/results?search_query=a` allow, `/feed/library`
  allow, `/playlist?list=PL1` allow, `/feed/subscriptions` home, `/` home, `/@x` allow, `/channel/UC1/shorts` →
  `/channel/UC1/videos`); CSS contains each required selector; CSS does **not** hide comment selectors; metadata block
  has `@run-at document-start` and both `@match` hosts; the banned-strings list above; the script file parses
  (`node --check`-equivalent via `new vm.Script`).

## 6. README (iPhone install, plain language, short)
1. App Store → install **Userscripts** (by Justin Wasack / quoid, free).
2. Open it once, pick its scripts folder (On My iPhone → Userscripts is fine).
3. Settings → Apps → Safari → Extensions → Userscripts → On, allow on `youtube.com` (All websites is fine).
4. In Safari open the raw script URL
   `https://raw.githubusercontent.com/stefikus67/instagram-utility-ios/main/killtube/killtube.user.js`, tap the
   **aA** / puzzle icon → Userscripts → install. (Or save the file into the Userscripts folder via Files.)
5. Open youtube.com in Safari, log in once, and in YouTube settings turn **Autoplay off** too.
6. Delete the YouTube app so YouTube links open in Safari. Optional: add youtube.com to the Home Screen
   (Share → Add to Home Screen) for an app-like icon.
7. Screen-off audio: start a video, lock the phone; if it pauses, press play on the lock screen.
Plus a short "what it does / what it doesn't" list and "if YouTube changes its layout, something may reappear — tell
Claude".

## Process
- Branch `killtube` from `main`. Small commits; each commit message ends with
  `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.
- Run `node --test` in `killtube/` before every commit (all green). Push the branch; confirm the `killtube` workflow is
  green. Open a PR to `main` titled "Killtube: Shorts-free search-only YouTube userscript" (body ends with the Claude
  Code attribution line). Do not merge.
- Final report: commits, test count, PR link, anything unsure (selectors are device-verified later by Stepan).
