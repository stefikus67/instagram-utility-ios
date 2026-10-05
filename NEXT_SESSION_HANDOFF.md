# Handoff — Instagram Utility

## State (2026-10-05)
- Milestone 1 (foundation) implemented per `docs/superpowers/plans/2026-10-05-m1-foundation.md`.
- CI: green on branch m1-foundation (not merged to main yet); run 37298454861, artifact `InstagramUtility-unsigned-ipa` (232 KB).
- Device checklist (`docs/IPHONE_INSTALL.md` §4): not yet run by the owner.

## Next
1. Owner runs the milestone 1 checklist on the iPhone 13 and reports.
2. DONE 2026-10-05: endpoint discovery. Results in `docs/notes/instagram-endpoints.md` (inbox, thread + paging, send text, send photo,
   search, profile/grid/highlights/suggested, stories tray + viewer, post story). All plain HTTP; no WebSocket seen. Gaps listed at the bottom of that file.
3. Write the next plan (Opus): InstagramClient (+ rate limiter, debounced search, token fetch for fb_dtsg/lsd) → live inbox → native chat → Find people (milestone 2).

## Must-fix items carried into the live-client plan (from milestone 1 reviews)
- InboxLoader writes the cache after a cancelled fetch; with real data a cache file could survive Reset. Fix: Reset awaits the in-flight reload task, or the cache uses a generation token (Task.checkCancellation alone leaves a window).
- Inbox reloads on every tab switch and not on return-from-background; spec §5 wants app-open + pull-to-refresh only. Also loses search text on tab switch.
- DiskCache lives in Application Support (backed up to iCloud). Move to Caches or set isExcludedFromBackup before real data.
- RelativeTimestamp builds a DateFormatter per row and `now` goes stale while the app is open — cache formatters, refresh `now`.
- Shared WKWebView moving between login sheet and web chat is fragile: use a container view and only detach in dismantleUIView if still its superview (M2).
- `lastDirectURL` survives across web-chat sessions ("Back to chat" may land on an old thread).
- Deferred polish: accessibility (selected-tab trait, labels on IconButton/SearchField, hide Avatar from VoiceOver), InboxStore has no unit tests, `webView.backgroundColor = .black` literal.
