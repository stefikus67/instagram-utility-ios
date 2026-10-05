# Handoff — Instagram Utility

## State (2026-10-05)
- Milestone 1 (foundation) implemented per `docs/superpowers/plans/2026-10-05-m1-foundation.md`.
- CI: green on branch m1-foundation (not merged to main yet); artifact `InstagramUtility-unsigned-ipa`.
- Device checklist (`docs/IPHONE_INSTALL.md` §4): not yet run by the owner.

## Next
1. Owner runs the milestone 1 checklist on the iPhone 13 and reports.
2. Endpoint-discovery session: owner logs into instagram.com in the desktop app's browser pane and uses
   DMs (inbox, a thread, sending text/photo/voice). Claude reads request names and response shapes only.
3. Write the next plan: InstagramClient (+ rate limiter) → live inbox → native chat (milestone 2).
