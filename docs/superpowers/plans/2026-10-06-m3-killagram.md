# Milestone 3 — Killagram (rebrand + fixable device-test failures)

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Checkbox steps.

**Goal:** Rebrand to "Killagram" (name + icon), and fix the device-test failures that are actually fixable on Instagram's mobile website: Find-people live search, the unread-only toggle, and story posting. Document the confirmed web limits (view-once media, live in-app camera) as out of scope.

**Context — live-DOM findings (2026-10-06, verified in the browser pane on mobile Instagram, Android UA, 375px):**
- **Unread marker:** an ~8px round element with `background-color: rgb(74, 93, 249)` (Instagram unread-blue) inside a chat row. Read rows have none. Row/list classes are obfuscated and unstable — the blue dot is the only stable signal. (The green `rgb(28,209,79)` dot is "active now" — do NOT use it.)
- **Find people:** `/explore/search/` on mobile web is a CLEAN account-search page — a search input (placeholder "Search"), Recent list, and account results as you type (`PolarisSearchBoxRefetchableQuery`). **No Explore grid** (`pageHasExploreGrid:false`). Tapping an account result opens `/<username>/` (profile, already allowed). This is the people-search-with-suggestions the owner wants.
- **Story posting:** `/create/story/` **redirects to `/` on mobile web** (feed) → the route guard then bounces to inbox = the "Post a story opens messages" bug. `/create/story/` works ONLY with a desktop UA. The create page is a self-contained full-screen upload UI (crop + "Share story") that renders fine at phone width. Fix: switch the webview's `customUserAgent` to desktop JUST while showing the create page, restore mobile UA on leave. No story-create entry exists in mobile-web home (`createLinks:[]`).
- **Composer:** mobile-web DM composer has "Add photo or video" (camera roll), "Voice clip", "Choose a GIF or sticker" — NOT in any nav/menubar, so our chrome-hide CSS does not hide them. There is NO live-camera-capture button on web (app-only). The DM view has NO bottom nav bar at all (`menubars:0`, no bottom-bar links).
- **Web limits (OUT OF SCOPE — document, don't attempt):** view-once ("tap to view") DM photos/videos are app-only on every Instagram web surface; live in-app camera capture is app-only. The owner accepted both.

**Spec:** `docs/superpowers/specs/2026-10-05-instagram-utility-v1-design.md` (§A website-based). This milestone extends it; update §A's dropped-features note with the confirmed web limits.

## Global Constraints
- Same as M2: €0; iOS 16; dark; no internal-API/token-read/request-replay/scraping; injected JS presentation-only (guardrail test); Theme tokens in native views; never log/display cookies/ids; feed/Explore(non-search)/Reels unreachable.
- `/explore/search/` becomes the ONE allowed Explore sub-route. `/explore/` and every other `/explore/<x>/` stay blocked.
- Commit trailer as this session specifies. Report files with full `C:\...` paths or reveal-in-Explorer; never relative, never VS Code.

## How to run — same as M2 (WSL `swift test`; CI build on push to branch `m3-killagram`). Baseline from main: 65 tests.

---

### Task 1: Rebrand to Killagram (name) + route policy for search
**Files:** Modify `project.yml` (CFBundleDisplayName → Killagram; PRODUCT_BUNDLE_IDENTIFIER may stay dev.instagramutility.app to avoid resign churn, or → dev.killagram.app — pick one, note it), scheme/target name may stay `InstagramUtility` internally (only the DISPLAY name must be Killagram) to avoid churning every file; Modify `Sources/RoutePolicy/InstagramRoutePolicy.swift` + tests.
**Interfaces:** `RouteCategory.searchAllowed = "SEARCH_ALLOWED"` (isAllowedInApp true); `classify` returns `.searchAllowed` for `/explore/search/` and `/explore/search/<anything>` ONLY; every other `/explore/...` stays `.blocked`. Add `InstagramRoutePolicy.searchURL = https://www.instagram.com/explore/search/`.
- [ ] TDD: tests — `/explore/search/`→.searchAllowed; `/explore/search/keyword/?q=x`→.searchAllowed; `/explore/`→.blocked; `/explore/tags/x/`→.blocked; `/explore/people/`→.blocked. A profile opened FROM search (`source=/explore/search/`) → media rule: a profile is `.profileAllowed` regardless of source, so `/<user>/` from search works; and media `/p/` from a profile still works. Add `.searchAllowed` as a VALID media source? NO — keep media sources to direct/profile/stories only (search→profile→media is the path).
- [ ] Implement: in `classify`, before the generic profile check, handle `first=="explore"`: if `segs[1]=="search"` → `.searchAllowed` else `.blocked`. Keep `explore` in `reservedFirstSegments`.
- [ ] project.yml: `CFBundleDisplayName: Killagram`. Note the bundle-id decision.
- [ ] WSL tests green; commit; push; CI green.

### Task 2: App icon (Killagram, Espresso style)
**Files:** Create `Sources/App/Resources/Assets.xcassets/AppIcon.appiconset/` with `icon-1024.png` + `Contents.json`; wire into `project.yml` (`settings.base.ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` and add the xcassets to the app target `sources`/`resources`).
- Icon design: Espresso v3 — near-black rounded-square (iOS applies the mask; supply a full-bleed 1024 with the warm-dark background `#14110f`→`#0c0a08`), a **gold** (`#ffdfa8`) rounded-square camera outline with a center circle lens and a small top accent, echoing Instagram's camera glyph but clearly our style (gold-on-espresso, not Instagram's gradient). No text. The 1024 PNG is produced by the controller (has image tooling + the pane); the implementer just wires the asset set + Contents.json + project.yml and confirms CI builds with it.
- [ ] Contents.json (single 1024 "ios-marketing" + the standard iPhone sizes can all reference the 1024 via a single-size set is NOT valid; use a proper appiconset — simplest reliable: a single 1024 marketing icon plus let Xcode/actool generate, OR list all required iPhone sizes pointing at appropriately scaled PNGs). The controller will supply the PNG(s). Implementer: create the appiconset referencing the provided file(s), wire project.yml, confirm CI build embeds the icon (check the build log / that actool runs without error).
- [ ] CI green with the icon.

### Task 3: Find people → Instagram's search
**Files:** Modify `Sources/App/FindPeople/FindPeopleView.swift`, `Sources/App/Web/WebSurfaceController.swift` (add `.search` to `Surface` → `searchURL`).
- Replace the native username field with: the shared web view showing `/explore/search/`. On the Find people tab appearing, `controller.show(.search)`. The user types in Instagram's own search box (real suggestions); tapping a result opens the profile (allowed). Keep a minimal native header ("Find people") above the web view, or none — match how Messages hosts the web view.
- Remove the old native SearchField + profileURL submit flow from FindPeopleView (profileURL stays in RoutePolicy, now unused by the UI — keep it, it's tested and harmless, or note removal).
- [ ] CI green. Device-verified later.

### Task 4: Unread-only fix (real marker)
**Files:** Modify `Sources/WebAssets/InjectedScripts.swift` (`unreadToggleJS` + paired CSS) + tests.
- Rewrite the unread detection: a chat row is UNREAD if it contains an element whose computed `background-color` is `rgb(74, 93, 249)` (Instagram unread-blue; allow a small tolerance, e.g. match `74, 93, 249`). When the toggle is on, hide rows that do NOT contain such an element. Identify "rows" defensively: find the thread-list container (the scroll area holding the chat rows under `/direct/inbox/`), treat its item-level descendants as rows; for each, mark `data-iu-unread="1"` if it contains the blue dot, else hide it when the attribute `data-iu-unread-only` is set on `<html>`. Re-run on the existing MutationObserver (already present) so it re-marks as the list hydrates. Null-guarded, try/catch, no polling, no cookie/token/fetch (guardrail test still passes). If no blue dot and no rows are found, no-op (never hide the whole inbox).
- Keep `window.__iuSetUnreadOnly(bool)` API and the controller's didFinish re-apply unchanged.
- [ ] Tests: guardrail test still passes; add an assertion that `unreadToggleJS` references the unread-blue signal (`74, 93, 249`). JSContext parse test still green.
- [ ] CI green. Device-verified later.

### Task 5: Story posting (targeted desktop UA)
**Files:** Modify `Sources/App/Web/WebSurfaceController.swift`.
- When `show(.create)`: set `webView.customUserAgent` to a desktop Safari UA (e.g. `"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHKTML, like Gecko) Version/17.0 Safari/605.1.15"` — use a real desktop Safari UA string), THEN load `InstagramRoutePolicy.createStoryURL`. The create page needs desktop UA or it redirects to `/`.
- When leaving the create surface (cover dismissed / show(any other)): restore the mobile UA (the app's normal `applicationNameForUserAgent`/customUserAgent). Confirm the create page still classifies `.createAllowed` and isn't bounced.
- The create page already needs the `orientationFixJS` (screen.orientation override) — confirm it still applies under desktop UA; if the create page uses desktop layout it may not need it, but keep it.
- The route guard posts `iuBlocked` for `/` — ensure that while on `.create`, a transient `/` during load doesn't bounce the user out before the create page loads (the desktop UA should prevent the redirect entirely; verify logic doesn't fight it).
- [ ] CI green. Device-verified later (the key check: Post a story now shows the upload/crop page, not the inbox).

### Task 6: Docs + device checklist + web-limits note
**Files:** `AGENTS.md`, `README.md`, `docs/IPHONE_INSTALL.md` §4 (M3 checklist), `NEXT_SESSION_HANDOFF.md`, spec §A dropped-features note.
- Spec §A / AGENTS: add confirmed web limits — view-once DM media and live in-app camera are app-only (not fixable in a web wrapper); story posting requires a desktop-UA page; search uses `/explore/search/`.
- Device checklist §4 (M3): rename shows "Killagram" + new icon on the home screen; Find people shows Instagram's search and suggests accounts as you type, tapping one opens the profile; unread-only hides read chats and persists; Post a story now opens the upload/crop screen (not the inbox) and you can post; confirm feed/Explore(non-search)/Reels still blocked; confirm a DM-sent reel still doesn't scroll to the next; note that view-once media and live-camera are known app-only limits.
- Record CI run id + artifact.

## Self-review checklist
1. Coverage: rename(1,2), search(1,3), unread(4), story(5), limits-doc(6). ✓
2. Firewall: only `/explore/search/` opened up; everything else in `/explore/` stays blocked (Task 1 tests pin this). ✓
3. Guardrail: Task 4 JS still presentation-only (blue-dot color read via getComputedStyle = reading styling, not auth; no cookie/token/fetch). ✓
4. Story desktop-UA is per-page and reverted — not "desktop style everywhere" (owner rejected that). ✓
