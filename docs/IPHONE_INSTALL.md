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
6. ~~Unread only toggle~~ — removed in M5 (owner: did not work, not needed).
7. ~~You → Post a story~~ — obsolete: story posting was removed in M4.
8. Settings → Reset Instagram Session → login returns (the You tab was Reset's home before M4).

KNOWN APP-ONLY LIMITS (not bugs): view-once "tap to view" DM photos/videos won't open (Instagram locks them to its app); there's no in-DM live camera (send from camera roll instead).

## 5. Milestone 4 device checklist (on the iPhone)
1. The app background is Instagram's dark navy; no colour seam between our title bars and Instagram's pages.
2. Find people: none of Instagram's bottom buttons (home/search/reels/profile) are visible or tappable.
3. Open Messages once, then You → your own Instagram profile opens (no story button anywhere).
4. Settings tab shows your @username, Diagnostics and Reset.
5. After Reset + login, You re-detects your username (open Messages once first).

## 6. Milestone 6 device checklist (on the iPhone)
1. You → tap + (top right of the header) → Instagram's home page opens with **no feed visible** and its New post / Story menu opens by itself. If it does not, a "Tap + at the top, then Story." hint shows; tap Instagram's + yourself.
2. Pick **Story** → Instagram's composer opens (you are not bounced to Messages or Find people).
3. Pick a photo, add text, share → the cover closes and Messages shows.
4. X closes the cover at any point, and the feed is never reachable (Instagram's Home/Reels taps bounce).
5. Settings → Diagnostics "Blocked navigations" still counts feed attempts outside the composer.
