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

## 4. Milestone 1 checklist (on the iPhone)
1. Install the new IPA in SideStore (it replaces the POC; your login may need to be redone once).
2. First launch: a sheet with Instagram's real login page. Log in (2FA as normal). The sheet closes.
3. Messages tab: dark Espresso design, "No chats here yet" and an Open web chat button.
4. Force-quit, reopen. **No login sheet** — you stay logged in.
   If the sheet flashes and then closes by itself, tell Claude — the app was still loading your saved login.
5. You → Preview → turn on **Show sample inbox**. Messages shows 5 sample chats and a stories row.
   Check the look: spacing, sizes, contrast. Note anything that feels off and in which direction.
6. Type "lu" in Search chats → only Luka remains.
7. Tap a chat → web chat opens full screen. Open a conversation, tap the message field:
   **the field and Send sit above the keyboard.** Close the keyboard: **Send is visible** (no tab bar).
8. In web chat, record a voice message (iOS asks for the microphone the first time).
9. Done → back in the app. You → Reset Instagram Session → confirm → the login sheet appears.
10. Only if it happens: if Instagram logs you out while web chat is open (web chat shows Instagram's login page), tap **Done**. The login sheet must appear. If it doesn't, tell Claude. Skip this step if it never happens.
Known and expected: in web chat you can still swipe from a shared reel to other reels. That is fixed
by the native viewer in milestone 3; web chat is only the fallback.
