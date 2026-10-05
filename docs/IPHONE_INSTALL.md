# Installing on your iPhone (SideStore, free Apple ID)

Cost: €0. No paid Apple Developer Program. Verify SideStore steps against https://docs.sidestore.io — they change.

## 1. One-time SideStore setup (skip if already installed)
Windows prerequisites per SideStore docs: 64-bit Windows, iTunes (Microsoft Store/Apple), the **iloader** installer,
your Apple ID, Wi-Fi. On the iPhone: install **LocalDevVPN** from the App Store.
1. Connect the iPhone by cable, trust the computer, enable Developer Mode (Settings → Privacy & Security).
2. Run iloader, sign in with your Apple ID, install SideStore onto the phone.
3. On the phone: trust the profile (Settings → General → VPN & Device Management), open SideStore.
LocalDevVPN must be **connected** whenever you install, update or refresh apps in SideStore.

## 2. Get the IPA
GitHub repo → Actions → latest green `build-ios` run → Artifacts → `InstagramUtility-unsigned-ipa` (a zip containing
`InstagramUtility-unsigned.ipa`). Get it onto the phone (AirDrop/iCloud Drive/Files).

## 3. Install
SideStore → My Apps → **+** → pick the IPA → it signs with your free Apple ID and installs.

## Free Apple ID limits
- Apps expire after **7 days**; refresh before then (SideStore → My Apps → Refresh, LocalDevVPN on).
- Free accounts allow only a small number of active App IDs (currently 3) and app installs per week; if installs fail
  with an App ID error, remove another sideloaded app.
- No push notifications via APNs (accepted for V1).

## 4. Milestone 2 device checklist (on the iPhone)
1. Install the new IPA in SideStore (LocalDevVPN on). Log in. Messages shows Instagram's inbox, and Instagram's own bottom nav bar is **not visible**.
2. Try to reach Home / Explore / Reels (tap any links). Each bounces back to a safe page; You → Diagnostics "Blocked navigations" goes up. Report any way through.
3. Open a chat; send a text and a photo; the field + Send sit above the keyboard; Send stays visible.
4. Open a reel someone sent you in a DM → it opens → swiping/scrolling does **not** move to another reel. (This was the main POC failure.) But a reel's comments / a post's caption should still scroll.
5. Find people → type a username → their profile opens (grid, highlights). Open one of their posts; it shows; you can't swipe to a stranger's post.
6. Open that person's stories/highlights; watch a few; closing returns cleanly; no jump into suggested content.
7. You → Post a story → pick a photo → it does **not** say "rotate your device" → post it (delete after). Close returns to Messages.
8. Messages → "Unread only" on → read chats hide. Relaunch the app → the toggle is still on.
9. You → Reset Instagram Session → confirm → the login page returns.

**Note which steps use injected JS** (1, 2, 4, 6, 7, 8) — if any misbehaves, report exactly what you saw; those are selector-dependent and may need a one-line follow-up tweak.
