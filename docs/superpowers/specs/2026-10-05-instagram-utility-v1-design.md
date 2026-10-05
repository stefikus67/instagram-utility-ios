# Instagram Utility v1 — Design Spec

Date: 2026-10-05 · Status: awaiting owner review · Supersedes the POC scope in `AGENTS.md`

## 1. Goal

A fast, native, premium-looking iPhone app for Instagram communication — DMs, stories, posting
stories, finding and viewing people — with no feed, Explore or Reels. It replaces the official
Instagram app on the owner's iPhone 13.

Success means: the owner deletes the official app and uses this daily; opening the app and opening a
chat feel instant; no path leads to algorithmic content.

### What the POC proved (2026-10-04 device test)
- Real Instagram login inside the app works; Reset Session works; DMs send.
- Home/Explore/Reels were unreachable.
- **Failed:** reel chaining inside DM media (Instagram's reel viewer changes reel without a URL change),
  keyboard covering the input, tab bar covering Send, and everything was "painfully slow".
- Not checked: session persistence across restart (test 2) — verify on the first v1 build.
- Instagram's mobile website (checked in Safari, 2026-10-05) supports voice recording in chats and
  posting stories (+ button).

## 2. Constraints (unchanged from the POC unless noted)

- €0: no paid Apple program, server, hosting, CI or dependency. Public GitHub repo, `macos-latest` CI,
  unsigned IPA, installed via SideStore with a free Apple ID (7-day refresh, 3 apps max).
- No backend; the phone app works alone.
- Never handle the Instagram password; login is always Instagram's own web page.
- Never log, display or commit cookies, session ids, tokens or user data.
- **Changed:** native screens use the internal endpoints that instagram.com itself calls, from the
  user's own logged-in session on the phone. The owner accepted the trade-offs: against Instagram's
  terms, endpoints can change without notice, some risk of temporary action blocks. Requests present
  as Instagram's website; the app never imitates the official mobile app's device signatures.

## 3. Product scope

### In v1
| Area | Contents |
|---|---|
| Inbox | Stories row (own circle first, + to post), notes bubbles above story circles, chat cards with unread dots, search across chats, pinned chats, message-requests folder, pull to refresh |
| Chat | Text, photos, videos, voice messages, replies, reactions (shown; double-tap to like), seen status. Send: camera (photo/video, in-app), camera roll, hold-to-record voice (slide to cancel). Tap media → full screen with Save. Shared posts/reels open in the single-item viewer |
| Stories viewer | Followed accounts only, Instagram's order. Tap fwd/back, hold to pause, swipe down to close. Ends after one person unless "continue to next" is on in Settings. Reply → DM |
| Notes | View friends' notes above their story circles; tap own circle to write/change own note |
| Story composer | Pick or take photo/video, crop 9:16, **text** (a few fonts and colours; drag, pinch, rotate), post. No stickers/music in v1 |
| Find people | Keyboard up on open, results as you type, suggested accounts shown before typing (short list, not a scroll) |
| Profiles | Photo, name, bio, counts, Follow/Message, highlights row (tap to view), full post grid incl. their reels. Post viewer swipes through **that person's** posts only. Like button in the viewer |
| Follow moment | Follow button morphs to a check with a gold ring pulse + light haptic, then becomes "Message". Search-result avatar grows into the profile header on open |
| You | Own profile, own stories with viewer list, Settings (notifications, story continue-to-next, call auto-reply text, Reset Session, Diagnostics), "Open web chat" backup |
| Notifications | Best-effort: iOS background refresh checks the inbox and posts local notifications. Timing is decided by iOS (≈15 min to hours) |
| Call auto-reply | On noticing a missed-call item in a thread (foreground or background check), send the owner-configured message once per missed call. Default text: "I don't take calls here, text me 🙂" |

### Not in v1 (deliberately absent — "capability does not exist")
Home feed, Explore, Reels feed, comments, making or receiving calls, channels, stickers/music in
stories, multiple accounts, automation beyond the call auto-reply, AI features.

Firewall rule: the user only ever sees content from a profile they deliberately opened or content
someone sent them. No suggestions under posts, no cross-account "next", no feed. Suggested accounts
in Find people is the one deliberate discovery exception, limited to a short non-scrolling list.

## 4. Visual design

Reference mockup: `docs/design/mockups/inbox-and-chat-v3.html` (inbox, open chat, typing state at
iPhone 13 size, 390×844 pt).

**Style:** "Espresso v3" — dark, warm, premium, maximum contrast. Serif large titles, rounded cards,
one gold accent. Floating pill tab bar with three tabs: **Messages · Find people · You**. The tab bar is
hidden inside a chat.

**Colour tokens** (contrast measured against their backgrounds; minimum allowed 4.5:1):

| Token | Value | Use | Measured contrast |
|---|---|---|---|
| bg | `#000000` | screen background | — |
| card | `#1d1814` | chat cards, input field | — |
| raise | `#26201b` | incoming bubbles, tab bar, icon buttons | — |
| text | `#ffffff` | names, message text | 17.6:1 on card |
| text2 | `#ddd2c6` | previews, story labels | 11.8:1 on card |
| text3 | `#c6b9ab` | times, inactive tabs, status | 9.2:1 on card, 8.4:1 on raise |
| placeholder | `#a99c8f` | field placeholders | 6.6:1 on card |
| gold | `#ffdfa8` | accent, own bubbles, active tab, unread dot | 12.6:1 on raise |
| goldInk | `#1a1007` | text/icons on gold | 14.6:1 on gold |
| coral | `#f2906f` | story ring gradient start (with gold) | decorative |
| border | `#2f2822` | input field outline, chat header divider | decorative |

**Proportion system** ("the ratios" — every size comes from these; enforced by tests, §7):
- Spacing steps: 2 · 4 · 8 · 12 · 16 · 24 · 32 pt only (2 is only for the gap between bubbles in a
  run). Screen edge margin 16 pt. Spacing = gaps, padding, margins. Component sizes (avatars, heights)
  and strokes are not spacing and are governed by the ratio rules below.
- Type scale: large title 34 (serif, New York) · body/name 17 (names semibold) · preview 15 · time 13 ·
  label 12 · tab label 10. Matches iOS Dynamic Type steps.
- Chat card: 72 pt tall, 52 pt avatar centred vertically (inset (72 − 52) / 2 = 10 pt, also used as
  the left padding), 8 pt between cards, 20 pt radius.
- Story circles: 68 pt (1.3× chat avatar), 3 pt ring, 3 pt gap, 56 pt avatar inside, 16 pt between
  circles, 4 pt to the name label.
- Radii: card 20 · search 12 · bubbles 20 · input field 20 · tab bar 32 (fully round). Nested radius =
  outer radius − padding.
- Tab bar: 64 pt tall, 24 pt from sides, 24 pt above the bottom edge, 24 pt icons.
- Chat: bubbles max 75% of width, 8/12 pt padding, 2 pt between messages in a run, 8 pt between runs.
  Input controls 40 pt. Camera button left (gold), gallery + mic inside the field, mic becomes the gold
  Send button while text is present. Input bar is pinned to the keyboard and moves with it.

## 5. Architecture

```
SwiftUI app (3 tabs) ──► Feature modules ──► InstagramClient ──► instagram.com internal web endpoints
                              │                    │
                              ▼                    ▼
                         Local cache        InstagramSession (hidden WKWebView,
                     (instant start)        persistent cookies, real login page)
```

Units (each one purpose, testable on its own):

1. **DesignSystem** — colour tokens, spacing, type, radii, reusable components (card, bubble, avatar,
   story ring, pill tab bar, buttons, follow animation). No other module defines a raw colour or size.
2. **InstagramSession** — the hidden persistent `WKWebView` holding the login. Shows Instagram's real
   login/checkpoint page when needed. Exposes auth state. Provides the session cookie to the client
   per request, in memory only.
3. **InstagramClient** — the only code that talks to Instagram. Typed requests per feature (inbox,
   thread, send text/media/voice, stories tray, story post, notes, search, profile, posts, highlights,
   like, follow, suggested accounts). Owns rate limiting and backoff. Has no feed/Explore/Reels
   requests at all.
4. **Cache** — local store of inbox, threads, profiles, story tray metadata; media thumbnails on disk.
   Screens render from cache first, then refresh. iOS file protection enabled.
5. **Feature modules** — Inbox, Chat, Stories, Notes, Composer, People (search/profile/grid/highlights/
   viewer), You/Settings. Each depends on DesignSystem + InstagramClient + Cache, never on each other
   except through navigation.
6. **Background** — `BGAppRefreshTask` inbox check → local notifications → call auto-reply.
7. **WebChatFallback** — the POC's web view + `InstagramRoutePolicy` firewall, reached from You →
   "Open web chat" and from any feature's "unavailable" state. Keyboard and tab-bar overlap bugs fixed.

**Request budget** (account-safety guardrails):
- Open thread on screen: check for new messages every 3–5 s; stops when the chat leaves the screen or
  the app backgrounds.
- Inbox: refresh on app open, pull-to-refresh, and background refresh only.
- Everything else: only in response to a user action.
- Global cap on requests per minute; on HTTP 429 or a "please wait" response, the affected feature
  stops automatic requests with exponential backoff and shows a notice.

**Endpoint discovery** (before building each feature): the owner logs into instagram.com in the
desktop app's browser pane (typing the password themselves) and uses that feature normally. Claude
reads the network request names and response shapes from the browser pane. Captured samples are
reduced to fixtures with fake names and no cookies, ids or tokens before being committed.

## 6. Error handling

| Situation | Behaviour |
|---|---|
| Instagram checkpoint / "confirm it's you" / logged out | Banner → opens Instagram's real page in the session web view. The app never bypasses challenges |
| Endpoint changed (unexpected response shape) | Only that feature shows "unavailable — use web chat". Diagnostics records the endpoint name, never content |
| Rate limited | Feature backs off, stops automatic requests, tells the user |
| Offline | Show cache. Outgoing messages queue, show pending/failed, retry |
| Media upload fails | Message marked failed with retry; nothing silently dropped |

## 7. Testing

- **Unit tests in CI** (`swift test`, no Instagram account): response parsing against sanitized fixtures,
  request building, rate limiter/backoff, call auto-reply rules (once per missed call, never loops),
  cache read/write.
- **Design token tests**: every text/background pair in the token table meets ≥ 4.5:1; every spacing,
  radius and font size used by DesignSystem is on the defined scale. Build fails on drift.
- **Firewall tests**: InstagramClient exposes no feed/Explore/Reels request; the post viewer only pages
  within the opened profile's posts; DM-shared media viewer has no next. Existing route policy tests
  stay for the web fallback.
- **On-device checklist per milestone**, run by the owner. A feature is not "done" until it passes on
  the iPhone 13.

## 8. Milestones (each = an installable build + device test)

1. DesignSystem, login, three-tab shell, inbox from cache (instant open). Includes POC test 2
   (session survives restart).
2. Native chat: text + photos, web-chat fallback (keyboard + tab-bar fixes).
3. Voice (record/play), video, save media, single-item viewer with likes.
4. Stories viewer + notes.
5. Story composer with text.
6. Find people, profiles, grid, highlights, suggested accounts, follow animation.
7. Background notifications + call auto-reply.

`AGENTS.md`, `README.md` and `docs/IPHONE_INSTALL.md` are updated in milestone 1 to match this spec.

## 9. Known risks

- Instagram can change internal endpoints at any time; features will break until fixed and reinstalled.
- Using internal endpoints violates Instagram's terms; mitigated (not removed) by human-scale request
  volume and website-like requests.
- New messages arrive with a few seconds' delay in an open chat and best-effort delay otherwise.
- Free SideStore signing: 7-day expiry, needs LocalDevVPN + Wi-Fi to refresh, 3-app limit.
- Every change needs CI → download → SideStore install to test, so the device test loop is slow.
