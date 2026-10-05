# Handoff — Instagram Utility

## State (2026-10-05)
- Milestone 1 (foundation) implemented per `docs/superpowers/plans/2026-10-05-m1-foundation.md`.
- CI: green on branch m1-foundation (not merged to main yet); run 37298454861, artifact `InstagramUtility-unsigned-ipa` (232 KB).
- Device checklist (`docs/IPHONE_INSTALL.md` §4): not yet run by the owner.

## Next
1. Owner runs the milestone 1 checklist on the iPhone 13 and reports.
2. Endpoint-discovery session: owner logs into instagram.com in the desktop app's browser pane and uses
   DMs (inbox, a thread, sending text/photo/voice). Claude reads request names and response shapes only.
3. Write the next plan: InstagramClient (+ rate limiter) → live inbox → native chat (milestone 2).

## Must-fix items carried into the live-client plan (from milestone 1 reviews)
- InboxLoader writes the cache after a cancelled fetch; with real data a cache file could survive Reset. Fix: Reset awaits the in-flight reload task, or the cache uses a generation token (Task.checkCancellation alone leaves a window).
- Inbox reloads on every tab switch and not on return-from-background; spec §5 wants app-open + pull-to-refresh only. Also loses search text on tab switch.
- DiskCache lives in Application Support (backed up to iCloud). Move to Caches or set isExcludedFromBackup before real data.
- RelativeTimestamp builds a DateFormatter per row and `now` goes stale while the app is open — cache formatters, refresh `now`.
- Shared WKWebView moving between login sheet and web chat is fragile: use a container view and only detach in dismantleUIView if still its superview (M2).
- `lastDirectURL` survives across web-chat sessions ("Back to chat" may land on an old thread).
- Deferred polish: accessibility (selected-tab trait, labels on IconButton/SearchField, hide Avatar from VoiceOver), InboxStore has no unit tests, `webView.backgroundColor = .black` literal.
