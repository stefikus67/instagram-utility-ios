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

## 4. Human verification checklist
1. Launch Instagram Utility → Messages tab shows Instagram's real login page (never give credentials to anyone else).
2. Log in (handle 2FA/challenge normally). Land on the DM inbox.
3. Force-quit and reopen → still logged in (session persisted). Settings → Session shows "Logged in".
4. Open a conversation; text and photos display.
5. Send a test message to yourself/a friend; it arrives.
6. Try to reach Home / Explore / Reels (tap bottom-bar icons, any links). Each must bounce back to a DM page;
   Settings → "Blocked navigations" increases. **Report any way in.**
7. Open a Reel/post someone sent in a DM → it opens once with "Back to chat". Try swiping/tapping to more reels → must be blocked.
8. Settings → Reset Instagram Session → confirm → logged out; log in again works.
9. After ≥1 day, refresh in SideStore; confirm the app still launches and stays logged in.

Never share your Instagram password or session data with anyone; do not paste cookies in issues.
