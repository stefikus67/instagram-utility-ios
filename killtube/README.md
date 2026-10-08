# Killtube

YouTube on the iPhone without Shorts and without rabbit holes. It keeps everything you pay for and use: login,
YouTube Premium, playlists, Watch later, history, comments.

Killtube is a userscript (`killtube.user.js`). It runs in **Safari** through the free **Userscripts** app. It only
hides parts of the YouTube page, redirects a few addresses, and styles a search box. It makes no network requests of
its own and never reads cookies or stored data.

## Install on the iPhone

1. App Store: install **Userscripts** (by Justin Wasack / quoid, free).
2. Open it once and pick its scripts folder (On My iPhone > Userscripts is fine).
3. Settings > Apps > Safari > Extensions > Userscripts: turn it **On** and allow it on `youtube.com`
   ("All websites" is fine).
4. In Safari open the raw script address:
   `https://raw.githubusercontent.com/stefikus67/instagram-utility-ios/main/killtube/killtube.user.js`
   Tap the **aA** / puzzle icon, then Userscripts, then install.
   (Or save the file into the Userscripts folder with the Files app.)
5. Open youtube.com in Safari, log in once, and in YouTube settings turn **Autoplay off** as well.
6. Delete the YouTube app so YouTube links open in Safari. Optional: add youtube.com to the Home Screen
   (Share > Add to Home Screen) for an app-like icon.
7. Screen-off audio: start a video, lock the phone. If it pauses, press play on the lock-screen player.

## What it does

- Start screen is a **search box only**. No home feed, no trending or explore, no gaming, no hashtag pages.
  The subscriptions feed is blocked too (open `killtube.user.js` and set `BLOCK_SUBSCRIPTIONS_FEED = false` to allow it).
- **No Shorts anywhere.** A `/shorts/<id>` link (for example one a friend sends you) opens as a normal single video.
  Shorts shelves, the Shorts nav item, Shorts chips and the channel Shorts tab are hidden; a channel's Shorts tab
  address opens its Videos tab instead.
- **No Up next.** Related videos and end-screen suggestions are hidden. If a video ends and YouTube jumps to the next
  one on its own within 8 seconds, with no tap from you, Killtube goes back once. It also switches the Autoplay toggle
  off when it sees it on.
- Keeps the page "visible" to YouTube so audio is more likely to keep playing with the screen off.
- Still works: login, Library (`/feed/library`, `/feed/you`, `/feed/playlists`, `/feed/history`), playlists, watch
  pages, search results, channel pages, comments, account pages.

## What it does not do

- It is not an ad blocker, and it does not touch Premium or your account.
- It cannot guarantee audio with the screen off. Safari decides. The fallback is the lock-screen play button.
- It does not remove videos YouTube puts in search results. Search is the whole point.
- It does not work in the YouTube app or in embedded players on other sites.

## If YouTube changes its layout

YouTube renames its page elements from time to time. The selectors in this script are best-effort and were measured
on 2026-10-08. If something reappears (a Shorts shelf, Up next, the home feed), tell Claude which page and what you
see; the fix is usually one line in `HIDE_SELECTORS`. The script is built so a stale selector just does nothing
and never breaks the page.

## For developers

```
cd killtube
npm test        # node --test, built-in test runner, no dependencies
```

Rules the tests enforce: no network calls, no cookie or storage access, no timers that poll, everything inside
try/catch, comments and the player are never hidden, redirects never loop.

## Troubleshooting: "nothing changed"
1. **Version**: you need 1.0.1 or newer. 1.0.0 injected into the page context, which YouTube's security policy
   (Trusted Types) blocks, so the script never ran. Reinstall from the raw URL above.
2. **File name**: in Files → your Userscripts folder the file must be `killtube.user.js` — not
   `killtube.user.js.txt` (Safari sometimes adds `.txt` when downloading). Rename it if so.
3. **Extension on**: Settings → Apps → Safari → Extensions → Userscripts → On, and "youtube.com" (or All Websites)
   set to **Allow**.
4. **Script on**: in Safari on youtube.com tap **aA** (or the puzzle icon) → Userscripts. It should list *Killtube*
   with its switch on. If Userscripts says the folder is not set, open the Userscripts app and pick the folder again.
5. Reload the YouTube tab (pull down) after any change.
