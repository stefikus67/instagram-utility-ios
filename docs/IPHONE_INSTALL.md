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

## 4. Milestone 3 device checklist (on the iPhone)
1. Install the new IPA in SideStore (LocalDevVPN on). The app on your home screen now shows "Killagram" and the new gold-camera icon.
2. Log in. Messages shows Instagram's inbox; no Instagram bottom nav bar.
3. Try to reach Home / Explore / Reels — each bounces back; Diagnostics "Blocked navigations" goes up.
4. Find people tab → Instagram's search appears → type a name → it suggests accounts as you type → tap one → their profile opens (grid, highlights). Open a post; you can't swipe to a stranger's post.
5. Open a reel someone sent in a DM → it opens → does NOT scroll to another reel; a post's caption/comments still scroll.
6. Messages → "Unread only" ON → read chats hide, unread stay. If nothing hides, report it (the marker may have changed). Relaunch → toggle still on.
7. You → Post a story → it opens the upload/crop screen (NOT the inbox) → pick a photo → post (delete after). Close returns to Messages.
8. You → Reset Instagram Session → login returns.

KNOWN APP-ONLY LIMITS (not bugs): view-once "tap to view" DM photos/videos won't open (Instagram locks them to its app); there's no in-DM live camera (send from camera roll instead).
