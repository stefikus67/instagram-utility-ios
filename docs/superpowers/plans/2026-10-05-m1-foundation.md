# Milestone 1 — Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the POC shell with the v1 foundation: an Espresso-v3 design system whose ratios are enforced by tests, a testable core data layer, login that persists across restarts, a three-tab floating-pill shell, a cache-first inbox (shown with sample data until the live inbox lands), and a fixed web-chat fallback.

**Architecture:** Pure-Swift packages (`DesignTokens`, `Core`, existing `RoutePolicy`) hold every testable rule and run under `swift test` on Linux and macOS. The iOS app target (XcodeGen, built only in CI) compiles those sources plus `Sources/App/**` into one module, so app code uses the types without `import`. The hidden `WKWebView` in `InstagramSession` keeps the real Instagram login; screens are native SwiftUI built only from `Theme` values.

**Tech Stack:** Swift 5.9 language mode, SwiftUI (iOS 16+), WebKit, XCTest, XcodeGen, GitHub Actions `macos-latest`. No third-party dependencies.

**Spec:** `docs/superpowers/specs/2026-10-05-instagram-utility-v1-design.md` (read §4 Visual design and §5 Architecture before starting).

**Out of scope for this plan (next plan, after the endpoint-discovery session):** `InstagramClient`, live inbox data, native chat, rate limiter. Writing those now would mean guessing Instagram's response shapes.

## Global Constraints

- €0: no paid services or dependencies; CI is the existing public-repo `macos-latest` workflow.
- iOS deployment target 16.0; iPhone only; dark UI only (`UIUserInterfaceStyle: Dark`).
- Never handle the Instagram password; login is Instagram's own page in the session web view.
- Never log, display or commit cookies, session ids, tokens or user data. Diagnostics show categories and counts only.
- Every colour, spacing, font size, radius and component size in app code comes from `Palette` / `Spacing` / `TypeScale` / `Radius` / `Metrics` (via `Theme`). No raw numbers or hex values in views.
- Spacing steps: 2 · 4 · 8 · 12 · 16 · 24 · 32 pt only. Text contrast ≥ 4.5:1.
- Feed / Explore / Reels code must not exist.
- Every commit message ends with the `Co-Authored-By:` trailer your session's instructions specify.
- When reporting files to the owner, write full `C:\Users\stepa\Desktop\AI\active\instagram-utility-ios\...` paths or open them with the editor tool; never relative links.

## How to run things

**Local tests (Windows host, Swift 6.0.3 in WSL — toolchain already installed):**

```bash
wsl -d Ubuntu -- bash -c 'export PATH=$HOME/swift/usr/bin:/usr/bin:/bin LD_LIBRARY_PATH=$HOME/swiftlibs; rm -rf ~/iu && mkdir ~/iu && cp -r /mnt/c/Users/stepa/Desktop/AI/active/instagram-utility-ios/{Package.swift,Sources,Tests} ~/iu/ && cd ~/iu && swift test 2>&1 | tail -40'
```

To run one test class, replace `swift test` with `swift test --filter <TestClassName>`.

**App build (only possible in CI):**

```bash
cd /c/Users/stepa/Desktop/AI/active/instagram-utility-ios && git push && sleep 8 && "/c/Program Files/GitHub CLI/gh.exe" run watch "$("/c/Program Files/GitHub CLI/gh.exe" run list --limit 1 --json databaseId --jq '.[0].databaseId')" --exit-status
```

If CI fails: `"/c/Program Files/GitHub CLI/gh.exe" run view --log-failed | tail -60`, fix the compile error, commit, push again.

## File structure after this plan

```
Package.swift                         targets: RoutePolicy, DesignTokens, Core (+ 3 test targets)
project.yml                           app target compiles Sources/App + the three package source dirs
Sources/
  DesignTokens/Colors.swift           RGB, contrastRatio, Palette (Espresso v3)
  DesignTokens/Layout.swift           Spacing, TypeScale, Radius, Metrics
  Core/Models.swift                   ThreadSummary, InboxSnapshot, InboxSource
  Core/InboxOrdering.swift            pinned first, newest first
  Core/InboxSearch.swift              chat search filter
  Core/RelativeTimestamp.swift        "12:41" / "Tue" / "28.9.26"
  Core/DiskCache.swift                JSON file cache with iOS file protection
  Core/InboxLoader.swift              cache-first load + refresh
  RoutePolicy/InstagramRoutePolicy.swift   (unchanged)
  App/App/InstagramUtilityApp.swift   entry, environment objects
  App/App/AppCache.swift              creates the DiskCache
  App/App/RootView.swift              3 tabs + pill bar + login sheet + web chat cover
  App/DesignSystem/Theme.swift        SwiftUI face of DesignTokens
  App/DesignSystem/Avatar.swift
  App/DesignSystem/StoryCircle.swift
  App/DesignSystem/ChatCard.swift
  App/DesignSystem/PillTabBar.swift   AppTab + floating bar
  App/DesignSystem/Controls.swift     IconButton, SearchField, GoldCapsuleButtonStyle, SettingsSection, ValueRow
  App/Inbox/InboxStore.swift
  App/Inbox/SampleData.swift          SampleInboxSource, SampleStories
  App/Inbox/StoriesRow.swift
  App/Inbox/InboxView.swift
  App/FindPeople/FindPeopleView.swift
  App/You/YouView.swift
  App/Session/InstagramSession.swift  (moved from App/Web, rewritten)
  App/Session/LoginView.swift
  App/WebChat/InstagramWebView.swift  (moved from App/Web)
  App/WebChat/NavigationGuard.swift   (moved from App/Web, + mic permission)
  App/WebChat/WebChatView.swift
  App/Diagnostics/DiagnosticsStore.swift   (unchanged)
Tests/
  RoutePolicyTests/…                  (unchanged)
  DesignTokensTests/ColorTests.swift
  DesignTokensTests/LayoutTests.swift
  CoreTests/InboxRulesTests.swift
  CoreTests/RelativeTimestampTests.swift
  CoreTests/DiskCacheTests.swift
  CoreTests/InboxLoaderTests.swift
```

Deleted: `Sources/App/App/MessagesView.swift`, `Sources/App/Settings/SettingsView.swift`.

---

### Task 1: Colour tokens with enforced contrast

**Files:**
- Modify: `Package.swift`
- Create: `Sources/DesignTokens/Colors.swift`
- Test: `Tests/DesignTokensTests/ColorTests.swift`

**Interfaces:**
- Produces: `public struct RGB: Equatable, Hashable { r, g, b: UInt8; init(hex: UInt32); init(r:g:b:); var relativeLuminance: Double }`, `public func contrastRatio(_ a: RGB, _ b: RGB) -> Double`, `public enum Palette` with static `RGB` members `bg, card, raise, text, text2, text3, placeholder, gold, goldInk, coral, border, seenRing, avatarTop, avatarBottom`, `Palette.minimumTextContrast: Double`, `Palette.textPairs: [(name: String, foreground: RGB, background: RGB)]`.

- [ ] **Step 1: Replace `Package.swift` with the three-target layout**

```swift
// swift-tools-version:5.9
import PackageDescription

// Pure-logic targets only, so `swift test` runs anywhere (Linux, macOS) without a simulator or Instagram.
// The iOS app is built from project.yml via XcodeGen and compiles these same source folders.
let package = Package(
    name: "InstagramUtilityCore",
    platforms: [.macOS(.v13), .iOS(.v16)],
    targets: [
        .target(name: "RoutePolicy", path: "Sources/RoutePolicy"),
        .target(name: "DesignTokens", path: "Sources/DesignTokens"),
        .target(name: "Core", path: "Sources/Core"),
        .testTarget(name: "RoutePolicyTests", dependencies: ["RoutePolicy"], path: "Tests/RoutePolicyTests"),
        .testTarget(name: "DesignTokensTests", dependencies: ["DesignTokens"], path: "Tests/DesignTokensTests"),
        .testTarget(name: "CoreTests", dependencies: ["Core"], path: "Tests/CoreTests"),
    ]
)
```

- [ ] **Step 2: Write the failing test** — `Tests/DesignTokensTests/ColorTests.swift`

```swift
import XCTest
@testable import DesignTokens

final class ColorTests: XCTestCase {
    func testHexParsing() {
        XCTAssertEqual(RGB(hex: 0x1d1814), RGB(r: 0x1d, g: 0x18, b: 0x14))
    }

    func testContrastExtremes() {
        XCTAssertEqual(contrastRatio(RGB(hex: 0x000000), RGB(hex: 0xffffff)), 21, accuracy: 0.01)
        XCTAssertEqual(contrastRatio(RGB(hex: 0x777777), RGB(hex: 0x777777)), 1, accuracy: 0.0001)
    }

    func testContrastIsSymmetric() {
        XCTAssertEqual(contrastRatio(Palette.gold, Palette.raise), contrastRatio(Palette.raise, Palette.gold), accuracy: 0.0001)
    }

    func testMatchesValuesMeasuredDuringDesign() {
        // Spec §4 colour table.
        XCTAssertEqual(contrastRatio(Palette.text, Palette.card), 17.6, accuracy: 0.1)
        XCTAssertEqual(contrastRatio(Palette.text2, Palette.card), 11.8, accuracy: 0.1)
        XCTAssertEqual(contrastRatio(Palette.goldInk, Palette.gold), 14.6, accuracy: 0.1)
    }

    func testEveryTextPairMeetsMinimum() {
        XCTAssertFalse(Palette.textPairs.isEmpty)
        for pair in Palette.textPairs {
            let ratio = contrastRatio(pair.foreground, pair.background)
            XCTAssertGreaterThanOrEqual(ratio, Palette.minimumTextContrast, "\(pair.name) is only \(ratio):1")
        }
    }
}
```

- [ ] **Step 3: Run it to make sure it fails**

Run the local test command with `--filter ColorTests`.
Expected: build failure, `cannot find 'RGB' in scope` (or "no such module").

- [ ] **Step 4: Implement** — `Sources/DesignTokens/Colors.swift`

```swift
import Foundation

/// An sRGB colour as 8-bit channels. A plain value so contrast can be unit-tested without UIKit.
public struct RGB: Equatable, Hashable {
    public let r: UInt8
    public let g: UInt8
    public let b: UInt8

    public init(r: UInt8, g: UInt8, b: UInt8) {
        self.r = r
        self.g = g
        self.b = b
    }

    public init(hex: UInt32) {
        self.init(r: UInt8((hex >> 16) & 0xFF), g: UInt8((hex >> 8) & 0xFF), b: UInt8(hex & 0xFF))
    }

    /// WCAG 2.x relative luminance.
    public var relativeLuminance: Double {
        func linear(_ channel: UInt8) -> Double {
            let s = Double(channel) / 255
            return s <= 0.03928 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }
}

/// WCAG contrast ratio between two colours, from 1 (identical) to 21 (black on white).
public func contrastRatio(_ a: RGB, _ b: RGB) -> Double {
    let la = a.relativeLuminance
    let lb = b.relativeLuminance
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
}

/// Espresso v3 — dark, warm, maximum contrast (spec §4).
public enum Palette {
    public static let bg = RGB(hex: 0x000000)
    public static let card = RGB(hex: 0x1d1814)
    public static let raise = RGB(hex: 0x26201b)
    public static let text = RGB(hex: 0xffffff)
    public static let text2 = RGB(hex: 0xddd2c6)
    public static let text3 = RGB(hex: 0xc6b9ab)
    public static let placeholder = RGB(hex: 0xa99c8f)
    public static let gold = RGB(hex: 0xffdfa8)
    public static let goldInk = RGB(hex: 0x1a1007)
    // Decorative only (never carry text):
    public static let coral = RGB(hex: 0xf2906f)
    public static let border = RGB(hex: 0x2f2822)
    public static let seenRing = RGB(hex: 0x3a322c)
    public static let avatarTop = RGB(hex: 0x4a3e33)
    public static let avatarBottom = RGB(hex: 0x2b241e)

    public static let minimumTextContrast = 4.5

    /// Every text-on-background combination the UI uses. Add new combinations here so the
    /// contrast test covers them.
    public static let textPairs: [(name: String, foreground: RGB, background: RGB)] = [
        ("title on bg", text, bg),
        ("name on card", text, card),
        ("preview on card", text2, card),
        ("story label on bg", text2, bg),
        ("time on card", text3, card),
        ("section label on bg", text3, bg),
        ("inactive tab on raise", text3, raise),
        ("placeholder on card", placeholder, card),
        ("active tab on raise", gold, raise),
        ("gold icon on raise", gold, raise),
        ("gold on bg", gold, bg),
        ("incoming bubble text", text, raise),
        ("own bubble text", goldInk, gold),
    ]
}
```

- [ ] **Step 5: Run the tests, expect PASS**

Run the local test command with `--filter ColorTests`. Expected: `Executed 5 tests, with 0 failures`.
Then run the full suite: the 16 existing `InstagramRoutePolicyTests` must still pass.

- [ ] **Step 6: Commit**

```bash
git add Package.swift Sources/DesignTokens/Colors.swift Tests/DesignTokensTests/ColorTests.swift
git commit -m "Add Espresso v3 colour tokens with enforced contrast"
```

---

### Task 2: Layout tokens with enforced ratios

**Files:**
- Create: `Sources/DesignTokens/Layout.swift`
- Test: `Tests/DesignTokensTests/LayoutTests.swift`

**Interfaces:**
- Produces: `public enum Spacing` (`xxs=2, xs=4, s=8, m=12, l=16, xl=24, xxl=32`, `scale: [Double]`, `screenEdge`), `public enum TypeScale` (`largeTitle=34, body=17, preview=15, time=13, label=12, tabLabel=10`, `all: [Double]`, `iOSSteps: Set<Double>`), `public enum Radius` (`card=20, search=12, bubble=20, field=20, tabBar=32`), `public enum Metrics` (sizes listed in the code below, plus `spacingValues: [(name: String, value: Double)]`). All values are `Double`.

- [ ] **Step 1: Write the failing test** — `Tests/DesignTokensTests/LayoutTests.swift`

```swift
import XCTest
@testable import DesignTokens

final class LayoutTests: XCTestCase {
    func testEverySpacingValueIsOnTheScale() {
        XCTAssertEqual(Spacing.scale, [2, 4, 8, 12, 16, 24, 32])
        for item in Metrics.spacingValues {
            XCTAssertTrue(Spacing.scale.contains(item.value), "\(item.name) = \(item.value) is off the spacing scale")
        }
    }

    func testTypeSizesAreIOSSteps() {
        for size in TypeScale.all {
            XCTAssertTrue(TypeScale.iOSSteps.contains(size), "font size \(size) is not an iOS step")
        }
    }

    func testPillShapesAreFullyRound() {
        XCTAssertEqual(Radius.tabBar, Metrics.tabBarHeight / 2)
        XCTAssertEqual(Radius.field, Metrics.inputControl / 2)
    }

    func testBubblesMatchCards() {
        XCTAssertEqual(Radius.bubble, Radius.card)
    }

    func testChatAvatarIsCentredInCard() {
        XCTAssertEqual(Metrics.chatAvatar + 2 * Metrics.chatAvatarInset, Metrics.chatCardHeight)
    }

    func testStoryCircleIsAboutOnePointThreeTimesTheChatAvatar() {
        XCTAssertEqual(Metrics.storyCircle / Metrics.chatAvatar, 1.3, accuracy: 0.02)
    }

    func testStoryAvatarFitsInsideRingAndGap() {
        XCTAssertEqual(Metrics.storyAvatar, Metrics.storyCircle - 2 * (Metrics.storyRing + Metrics.storyRingGap))
    }

    func testTabBarContentFits() {
        XCTAssertLessThanOrEqual(Metrics.tabIcon + Spacing.xs + TypeScale.tabLabel + 2 * Spacing.s, Metrics.tabBarHeight)
    }

    func testBubbleWidthLimit() {
        XCTAssertEqual(Metrics.bubbleMaxWidthFraction, 0.75)
    }
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run with `--filter LayoutTests`. Expected: build failure, `cannot find 'Spacing' in scope`.

- [ ] **Step 3: Implement** — `Sources/DesignTokens/Layout.swift`

```swift
import Foundation

/// Gaps, padding and margins. Nothing in between these steps (spec §4).
public enum Spacing {
    public static let xxs: Double = 2   // only between bubbles in a run
    public static let xs: Double = 4
    public static let s: Double = 8
    public static let m: Double = 12
    public static let l: Double = 16
    public static let xl: Double = 24
    public static let xxl: Double = 32
    public static let scale: [Double] = [xxs, xs, s, m, l, xl, xxl]
    public static let screenEdge: Double = l
}

/// Font sizes in points; the same steps iOS uses at the default text size.
public enum TypeScale {
    public static let largeTitle: Double = 34   // serif
    public static let body: Double = 17         // names (semibold), message text
    public static let preview: Double = 15
    public static let time: Double = 13
    public static let label: Double = 12
    public static let tabLabel: Double = 10     // iOS tab bar label size
    public static let all: [Double] = [largeTitle, body, preview, time, label, tabLabel]
    public static let iOSSteps: Set<Double> = [34, 28, 22, 20, 17, 16, 15, 13, 12, 11, 10]
}

public enum Radius {
    public static let card: Double = 20
    public static let search: Double = 12
    public static let bubble: Double = 20
    public static let field: Double = 20     // fully round at inputControl height
    public static let tabBar: Double = 32    // fully round at tabBarHeight
}

/// Component sizes. Sizes are free of the spacing scale but tied together by ratio tests.
public enum Metrics {
    // Chat card
    public static let chatCardHeight: Double = 72
    public static let chatAvatar: Double = 52
    public static let chatAvatarInset: Double = 10   // (72 - 52) / 2, also the card's left padding
    public static let cardGap: Double = Spacing.s
    public static let unreadDot: Double = 10

    // Stories
    public static let storyCircle: Double = 68
    public static let storyRing: Double = 3
    public static let storyRingGap: Double = 3
    public static let storyAvatar: Double = 56
    public static let storyGap: Double = Spacing.l
    public static let storyLabelGap: Double = Spacing.xs
    public static let plusBadge: Double = 22
    public static let plusBadgeBorder: Double = 2

    // Tab bar
    public static let tabBarHeight: Double = 64
    public static let tabBarSide: Double = Spacing.xl
    public static let tabBarBottom: Double = Spacing.xl
    public static let tabIcon: Double = 24

    // Controls
    public static let iconButton: Double = 36
    public static let searchHeight: Double = 36
    public static let inputControl: Double = 40

    // Chat bubbles (used from milestone 2)
    public static let bubbleMaxWidthFraction: Double = 0.75
    public static let bubblePaddingV: Double = Spacing.s
    public static let bubblePaddingH: Double = Spacing.m
    public static let runGap: Double = Spacing.xxs
    public static let groupGap: Double = Spacing.s

    /// Every spacing-type metric, checked against `Spacing.scale` by the tests.
    public static let spacingValues: [(name: String, value: Double)] = [
        ("screenEdge", Spacing.screenEdge),
        ("cardGap", cardGap),
        ("storyGap", storyGap),
        ("storyLabelGap", storyLabelGap),
        ("tabBarSide", tabBarSide),
        ("tabBarBottom", tabBarBottom),
        ("bubblePaddingV", bubblePaddingV),
        ("bubblePaddingH", bubblePaddingH),
        ("runGap", runGap),
        ("groupGap", groupGap),
    ]
}
```

- [ ] **Step 4: Run the tests, expect PASS**

Run with `--filter LayoutTests`. Expected: `Executed 9 tests, with 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add Sources/DesignTokens/Layout.swift Tests/DesignTokensTests/LayoutTests.swift
git commit -m "Add layout tokens with ratio tests"
```

---

### Task 3: Core inbox rules (models, ordering, search, timestamps)

**Files:**
- Create: `Sources/Core/Models.swift`, `Sources/Core/InboxOrdering.swift`, `Sources/Core/InboxSearch.swift`, `Sources/Core/RelativeTimestamp.swift`
- Test: `Tests/CoreTests/InboxRulesTests.swift`, `Tests/CoreTests/RelativeTimestampTests.swift`

**Interfaces:**
- Produces:
  - `public struct ThreadSummary: Codable, Equatable, Identifiable` with `id: String, title: String, avatarURL: URL?, lastMessagePreview: String, lastActivity: Date, isUnread: Bool, isPinned: Bool` and a public memberwise `init` in that order.
  - `public struct InboxSnapshot: Codable, Equatable { var threads: [ThreadSummary]; var fetchedAt: Date }` with public `init(threads:fetchedAt:)`.
  - `public protocol InboxSource { func fetchInbox() async throws -> InboxSnapshot }`.
  - `public enum InboxOrdering { static func sorted(_: [ThreadSummary]) -> [ThreadSummary] }`.
  - `public enum InboxSearch { static func filter(_: [ThreadSummary], query: String) -> [ThreadSummary] }`.
  - `public enum RelativeTimestamp { static func string(for: Date, now: Date, calendar: Calendar, locale: Locale) -> String }`.

- [ ] **Step 1: Write the failing tests**

`Tests/CoreTests/InboxRulesTests.swift`:

```swift
import XCTest
@testable import Core

func makeThread(_ id: String, title: String? = nil, preview: String = "hi",
                minutesAgo: Double = 0, pinned: Bool = false, unread: Bool = false) -> ThreadSummary {
    let base = Date(timeIntervalSinceReferenceDate: 800_000_000)
    return ThreadSummary(id: id, title: title ?? id, avatarURL: nil, lastMessagePreview: preview,
                         lastActivity: base.addingTimeInterval(-minutesAgo * 60), isUnread: unread, isPinned: pinned)
}

final class InboxRulesTests: XCTestCase {
    func testNewestFirst() {
        let sorted = InboxOrdering.sorted([makeThread("old", minutesAgo: 60), makeThread("new", minutesAgo: 1)])
        XCTAssertEqual(sorted.map(\.id), ["new", "old"])
    }

    func testPinnedBeforeNewer() {
        let sorted = InboxOrdering.sorted([
            makeThread("recent", minutesAgo: 1),
            makeThread("pinnedOld", minutesAgo: 600, pinned: true),
        ])
        XCTAssertEqual(sorted.map(\.id), ["pinnedOld", "recent"])
    }

    func testTiesAreStableById() {
        let sorted = InboxOrdering.sorted([makeThread("b"), makeThread("a")])
        XCTAssertEqual(sorted.map(\.id), ["a", "b"])
    }

    func testEmptyQueryReturnsAll() {
        let threads = [makeThread("a"), makeThread("b")]
        XCTAssertEqual(InboxSearch.filter(threads, query: "   "), threads)
    }

    func testSearchMatchesTitleCaseInsensitively() {
        let threads = [makeThread("1", title: "Luka"), makeThread("2", title: "Maja")]
        XCTAssertEqual(InboxSearch.filter(threads, query: "lu").map(\.id), ["1"])
    }

    func testSearchMatchesPreview() {
        let threads = [makeThread("1", title: "Ana", preview: "see you saturday"), makeThread("2", title: "Tim")]
        XCTAssertEqual(InboxSearch.filter(threads, query: "Saturday").map(\.id), ["1"])
    }
}
```

`Tests/CoreTests/RelativeTimestampTests.swift`:

```swift
import XCTest
@testable import Core

final class RelativeTimestampTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    private let locale = Locale(identifier: "en_US_POSIX")

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 12, _ mi: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }

    // 2026-10-05 is a Monday.
    private var now: Date { date(2026, 10, 5, 15, 0) }

    private func s(_ d: Date) -> String {
        RelativeTimestamp.string(for: d, now: now, calendar: calendar, locale: locale)
    }

    func testSameDayShowsTime() { XCTAssertEqual(s(date(2026, 10, 5, 9, 7)), "09:07") }
    func testYesterdayShowsWeekday() { XCTAssertEqual(s(date(2026, 10, 4, 23, 59)), "Sun") }
    func testSixDaysAgoShowsWeekday() { XCTAssertEqual(s(date(2026, 9, 29)), "Tue") }
    func testSevenDaysAgoShowsDate() { XCTAssertEqual(s(date(2026, 9, 28)), "28.9.26") }
    func testFutureShowsDate() { XCTAssertEqual(s(date(2026, 10, 9)), "9.10.26") }
}
```

- [ ] **Step 2: Run them to make sure they fail**

Run the local test command with `--filter InboxRulesTests`. Expected: build failure, `cannot find 'ThreadSummary' in scope`.

- [ ] **Step 3: Implement**

`Sources/Core/Models.swift`:

```swift
import Foundation

/// One row of the inbox. Holds only what the inbox screen shows.
public struct ThreadSummary: Codable, Equatable, Identifiable {
    public let id: String
    public var title: String
    public var avatarURL: URL?
    public var lastMessagePreview: String
    public var lastActivity: Date
    public var isUnread: Bool
    public var isPinned: Bool

    public init(id: String, title: String, avatarURL: URL?, lastMessagePreview: String,
                lastActivity: Date, isUnread: Bool, isPinned: Bool) {
        self.id = id
        self.title = title
        self.avatarURL = avatarURL
        self.lastMessagePreview = lastMessagePreview
        self.lastActivity = lastActivity
        self.isUnread = isUnread
        self.isPinned = isPinned
    }
}

public struct InboxSnapshot: Codable, Equatable {
    public var threads: [ThreadSummary]
    public var fetchedAt: Date

    public init(threads: [ThreadSummary], fetchedAt: Date) {
        self.threads = threads
        self.fetchedAt = fetchedAt
    }
}

/// Where inbox data comes from. The live implementation arrives with InstagramClient (next plan).
public protocol InboxSource {
    func fetchInbox() async throws -> InboxSnapshot
}
```

`Sources/Core/InboxOrdering.swift`:

```swift
import Foundation

public enum InboxOrdering {
    /// Pinned chats first, then most recent activity first; ties broken by id so order is stable.
    public static func sorted(_ threads: [ThreadSummary]) -> [ThreadSummary] {
        threads.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            if a.lastActivity != b.lastActivity { return a.lastActivity > b.lastActivity }
            return a.id < b.id
        }
    }
}
```

`Sources/Core/InboxSearch.swift`:

```swift
import Foundation

public enum InboxSearch {
    /// Case-insensitive match on the chat name or the last message. Blank query returns everything.
    public static func filter(_ threads: [ThreadSummary], query: String) -> [ThreadSummary] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return threads }
        return threads.filter {
            $0.title.localizedCaseInsensitiveContains(q) || $0.lastMessagePreview.localizedCaseInsensitiveContains(q)
        }
    }
}
```

`Sources/Core/RelativeTimestamp.swift`:

```swift
import Foundation

public enum RelativeTimestamp {
    /// Today → "09:07", the previous six days → "Tue", older or future → "28.9.26".
    public static func string(for date: Date, now: Date, calendar: Calendar, locale: Locale) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return format(date, "HH:mm", calendar, locale) }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date),
                                           to: calendar.startOfDay(for: now)).day ?? Int.max
        if (1...6).contains(days) { return format(date, "EEE", calendar, locale) }
        return format(date, "d.M.yy", calendar, locale)
    }

    private static func format(_ date: Date, _ pattern: String, _ calendar: Calendar, _ locale: Locale) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.locale = locale
        f.dateFormat = pattern
        return f.string(from: date)
    }
}
```

- [ ] **Step 4: Run the tests, expect PASS**

Full local suite. Expected: all `InboxRulesTests` (6) and `RelativeTimestampTests` (5) pass, nothing else broken.

- [ ] **Step 5: Commit**

```bash
git add Sources/Core Tests/CoreTests
git commit -m "Add core inbox models, ordering, search and timestamps"
```

---

### Task 4: Cache-first inbox loading

**Files:**
- Create: `Sources/Core/DiskCache.swift`, `Sources/Core/InboxLoader.swift`
- Test: `Tests/CoreTests/DiskCacheTests.swift`, `Tests/CoreTests/InboxLoaderTests.swift`

**Interfaces:**
- Consumes: `ThreadSummary`, `InboxSnapshot`, `InboxSource`, `InboxOrdering` (Task 3), `makeThread` test helper (Task 3).
- Produces:
  - `public final class DiskCache { init(directory: URL) throws; func save<T: Encodable>(_: T, forKey: String) throws; func load<T: Decodable>(_: T.Type, forKey: String) -> T?; func removeAll() throws }`.
  - `public struct InboxLoader { init(cache: DiskCache, source: InboxSource, cacheKey: String = InboxLoader.defaultCacheKey); static let defaultCacheKey = "inbox"; func cached() -> InboxSnapshot?; func refresh() async throws -> InboxSnapshot }`.

- [ ] **Step 1: Write the failing tests**

`Tests/CoreTests/DiskCacheTests.swift`:

```swift
import XCTest
@testable import Core

final class DiskCacheTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testRoundTrip() throws {
        let cache = try DiskCache(directory: dir)
        let snap = InboxSnapshot(threads: [makeThread("a", unread: true)], fetchedAt: Date())
        try cache.save(snap, forKey: "inbox")
        XCTAssertEqual(cache.load(InboxSnapshot.self, forKey: "inbox"), snap)
    }

    func testMissingKeyReturnsNil() throws {
        XCTAssertNil(try DiskCache(directory: dir).load(InboxSnapshot.self, forKey: "nope"))
    }

    func testCorruptFileReturnsNil() throws {
        let cache = try DiskCache(directory: dir)
        try Data("not json".utf8).write(to: dir.appendingPathComponent("inbox.json"))
        XCTAssertNil(cache.load(InboxSnapshot.self, forKey: "inbox"))
    }

    func testRemoveAll() throws {
        let cache = try DiskCache(directory: dir)
        try cache.save(InboxSnapshot(threads: [], fetchedAt: Date()), forKey: "inbox")
        try cache.removeAll()
        XCTAssertNil(cache.load(InboxSnapshot.self, forKey: "inbox"))
    }
}
```

`Tests/CoreTests/InboxLoaderTests.swift`:

```swift
import XCTest
@testable import Core

private struct FakeSource: InboxSource {
    let result: Result<InboxSnapshot, Error>
    func fetchInbox() async throws -> InboxSnapshot { try result.get() }
}

private struct Boom: Error {}

final class InboxLoaderTests: XCTestCase {
    private var cache: DiskCache!

    override func setUpWithError() throws {
        cache = try DiskCache(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true))
    }

    override func tearDownWithError() throws {
        try? cache.removeAll()
    }

    func testCachedIsNilBeforeFirstRefresh() {
        let loader = InboxLoader(cache: cache, source: FakeSource(result: .failure(Boom())))
        XCTAssertNil(loader.cached())
    }

    func testRefreshSortsAndSaves() async throws {
        let fetched = InboxSnapshot(threads: [makeThread("old", minutesAgo: 60), makeThread("new", minutesAgo: 1)],
                                    fetchedAt: Date(timeIntervalSinceReferenceDate: 1))
        let loader = InboxLoader(cache: cache, source: FakeSource(result: .success(fetched)))
        let result = try await loader.refresh()
        XCTAssertEqual(result.threads.map(\.id), ["new", "old"])
        XCTAssertEqual(loader.cached(), result)
    }

    func testFailedRefreshKeepsPreviousCache() async throws {
        let good = InboxSnapshot(threads: [makeThread("a")], fetchedAt: Date(timeIntervalSinceReferenceDate: 1))
        _ = try await InboxLoader(cache: cache, source: FakeSource(result: .success(good))).refresh()
        let failing = InboxLoader(cache: cache, source: FakeSource(result: .failure(Boom())))
        do { _ = try await failing.refresh(); XCTFail("expected error") } catch {}
        XCTAssertEqual(failing.cached(), good)
    }

    func testCacheKeysAreIndependent() async throws {
        let snap = InboxSnapshot(threads: [makeThread("sample")], fetchedAt: Date(timeIntervalSinceReferenceDate: 1))
        _ = try await InboxLoader(cache: cache, source: FakeSource(result: .success(snap)), cacheKey: "inbox-sample").refresh()
        XCTAssertNil(InboxLoader(cache: cache, source: FakeSource(result: .failure(Boom()))).cached())
    }
}
```

- [ ] **Step 2: Run them to make sure they fail**

Expected: build failure, `cannot find 'DiskCache' in scope`.

- [ ] **Step 3: Implement**

`Sources/Core/DiskCache.swift`:

```swift
import Foundation

/// Small JSON-file cache. One file per key inside `directory`. On iOS files are encrypted by the
/// system until the phone is first unlocked after boot.
public final class DiskCache {
    private let directory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(directory: URL) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func save<T: Encodable>(_ value: T, forKey key: String) throws {
        let data = try encoder.encode(value)
        #if os(iOS)
        try data.write(to: url(for: key), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: url(for: key), options: .atomic)
        #endif
    }

    /// Missing or unreadable entries return nil; a stale cache must never crash the app.
    public func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = try? Data(contentsOf: url(for: key)) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    public func removeAll() throws {
        let items = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        for item in items { try FileManager.default.removeItem(at: item) }
    }

    private func url(for key: String) -> URL {
        directory.appendingPathComponent(key + ".json")
    }
}
```

`Sources/Core/InboxLoader.swift`:

```swift
import Foundation

/// Cache-first inbox: `cached()` is instant for app start, `refresh()` fetches, sorts and saves.
public struct InboxLoader {
    public static let defaultCacheKey = "inbox"

    private let cache: DiskCache
    private let source: InboxSource
    private let cacheKey: String

    public init(cache: DiskCache, source: InboxSource, cacheKey: String = InboxLoader.defaultCacheKey) {
        self.cache = cache
        self.source = source
        self.cacheKey = cacheKey
    }

    public func cached() -> InboxSnapshot? {
        cache.load(InboxSnapshot.self, forKey: cacheKey)
    }

    /// On failure the previous cache is left untouched and the error is rethrown.
    public func refresh() async throws -> InboxSnapshot {
        var snapshot = try await source.fetchInbox()
        snapshot.threads = InboxOrdering.sorted(snapshot.threads)
        try cache.save(snapshot, forKey: cacheKey)
        return snapshot
    }
}
```

- [ ] **Step 4: Run the full local suite, expect PASS**

Expected: DiskCacheTests 4, InboxLoaderTests 4, all earlier tests still pass.

- [ ] **Step 5: Commit and confirm CI still green** (CI runs `swift test`; the app target does not include Core yet, so it is unaffected)

```bash
git add Sources/Core Tests/CoreTests
git commit -m "Add disk cache and cache-first inbox loader"
```

Then run the CI command from "How to run things". Expected: run succeeds.

---

### Task 5: SwiftUI design system

**Files:**
- Modify: `project.yml`
- Create: `Sources/App/DesignSystem/Theme.swift`, `Avatar.swift`, `StoryCircle.swift`, `ChatCard.swift`, `PillTabBar.swift`, `Controls.swift`

**Interfaces:**
- Consumes: everything from Tasks 1–3 (same module in the app target, no imports).
- Produces: `extension Color { init(_ rgb: RGB) }`; `enum Theme` with `Color` statics `bg, card, raise, text, text2, text3, placeholder, gold, goldInk, border, seenRing`, `storyRingGradient: LinearGradient`, `avatarGradient: LinearGradient`, fonts `largeTitle, name, body, preview, previewUnread, time, label, tabLabel`; views `Avatar(url:size:)`, `StoryCircle(name:avatarURL:kind:)` with `enum Kind { case unseen, seen, own }`, `ChatCard(thread:timestamp:)`, `enum AppTab: CaseIterable, Hashable { case messages, findPeople, you }`, `PillTabBar(selection: Binding<AppTab>)`, `IconButton(systemImage:action:)`, `SearchField(text:placeholder:)`, `GoldCapsuleButtonStyle`, `SettingsSection(title:content:)`, `ValueRow(title:value:)`.

There is no unit test target for SwiftUI views; verification is the CI app build in Step 4 and the device checklist in Task 8.

- [ ] **Step 1: Update `project.yml`** — replace the `sources` list and add the dark-mode key under `info.properties`:

```yaml
    sources:
      - Sources/App
      - Sources/RoutePolicy
      - Sources/DesignTokens
      - Sources/Core
```

and add, next to `CFBundleDisplayName`:

```yaml
        UIUserInterfaceStyle: Dark
```

- [ ] **Step 2: Create the files**

`Sources/App/DesignSystem/Theme.swift`:

```swift
import SwiftUI

extension Color {
    init(_ rgb: RGB) {
        self.init(.sRGB, red: Double(rgb.r) / 255, green: Double(rgb.g) / 255, blue: Double(rgb.b) / 255, opacity: 1)
    }
}

/// The SwiftUI face of DesignTokens. Views use only these values — never raw colours or numbers.
enum Theme {
    static let bg = Color(Palette.bg)
    static let card = Color(Palette.card)
    static let raise = Color(Palette.raise)
    static let text = Color(Palette.text)
    static let text2 = Color(Palette.text2)
    static let text3 = Color(Palette.text3)
    static let placeholder = Color(Palette.placeholder)
    static let gold = Color(Palette.gold)
    static let goldInk = Color(Palette.goldInk)
    static let border = Color(Palette.border)
    static let seenRing = Color(Palette.seenRing)

    static let storyRingGradient = LinearGradient(colors: [Color(Palette.coral), Color(Palette.gold)],
                                                  startPoint: .topLeading, endPoint: .bottomTrailing)
    static let avatarGradient = LinearGradient(colors: [Color(Palette.avatarTop), Color(Palette.avatarBottom)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)

    static let largeTitle = Font.system(size: TypeScale.largeTitle, weight: .medium, design: .serif)
    static let name = Font.system(size: TypeScale.body, weight: .semibold)
    static let body = Font.system(size: TypeScale.body)
    static let preview = Font.system(size: TypeScale.preview)
    static let previewUnread = Font.system(size: TypeScale.preview, weight: .medium)
    static let time = Font.system(size: TypeScale.time)
    static let label = Font.system(size: TypeScale.label)
    static let tabLabel = Font.system(size: TypeScale.tabLabel, weight: .medium)
}
```

`Sources/App/DesignSystem/Avatar.swift`:

```swift
import SwiftUI

struct Avatar: View {
    let url: URL?
    let size: Double

    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                Theme.avatarGradient
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
```

`Sources/App/DesignSystem/StoryCircle.swift`:

```swift
import SwiftUI

struct StoryCircle: View {
    enum Kind { case unseen, seen, own }

    let name: String
    let avatarURL: URL?
    let kind: Kind

    var body: some View {
        VStack(spacing: Metrics.storyLabelGap) {
            circle.frame(width: Metrics.storyCircle, height: Metrics.storyCircle)
            Text(name)
                .font(Theme.label)
                .foregroundStyle(Theme.text2)
                .lineLimit(1)
                .frame(width: Metrics.storyCircle)
        }
    }

    @ViewBuilder private var circle: some View {
        switch kind {
        case .own:
            Avatar(url: avatarURL, size: Metrics.storyCircle)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "plus")
                        .font(.system(size: TypeScale.label, weight: .bold))
                        .foregroundStyle(Theme.goldInk)
                        .frame(width: Metrics.plusBadge, height: Metrics.plusBadge)
                        .background(Circle().fill(Theme.gold))
                        .overlay(Circle().stroke(Theme.bg, lineWidth: Metrics.plusBadgeBorder))
                }
        case .unseen, .seen:
            ZStack {
                Circle().fill(kind == .unseen ? AnyShapeStyle(Theme.storyRingGradient) : AnyShapeStyle(Theme.seenRing))
                Circle().fill(Theme.bg)
                    .frame(width: Metrics.storyCircle - 2 * Metrics.storyRing,
                           height: Metrics.storyCircle - 2 * Metrics.storyRing)
                Avatar(url: avatarURL, size: Metrics.storyAvatar)
            }
        }
    }
}
```

`Sources/App/DesignSystem/ChatCard.swift`:

```swift
import SwiftUI

struct ChatCard: View {
    let thread: ThreadSummary
    let timestamp: String

    var body: some View {
        HStack(spacing: Spacing.m) {
            Avatar(url: thread.avatarURL, size: Metrics.chatAvatar)
            VStack(alignment: .leading, spacing: 0) {
                Text(thread.title)
                    .font(Theme.name)
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text(thread.lastMessagePreview)
                    .font(thread.isUnread ? Theme.previewUnread : Theme.preview)
                    .foregroundStyle(thread.isUnread ? Theme.text : Theme.text2)
                    .lineLimit(1)
            }
            Spacer(minLength: Spacing.s)
            VStack(alignment: .trailing, spacing: Spacing.s) {
                Text(timestamp).font(Theme.time).foregroundStyle(Theme.text3)
                if thread.isUnread {
                    Circle().fill(Theme.gold).frame(width: Metrics.unreadDot, height: Metrics.unreadDot)
                }
            }
        }
        .padding(.leading, Metrics.chatAvatarInset)
        .padding(.trailing, Spacing.l)
        .frame(height: Metrics.chatCardHeight)
        .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Theme.card))
        .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}
```

`Sources/App/DesignSystem/PillTabBar.swift`:

```swift
import SwiftUI

/// The only three destinations in the app (spec §4). There is deliberately no feed, Explore or Reels tab.
enum AppTab: CaseIterable, Hashable {
    case messages, findPeople, you

    var title: String {
        switch self {
        case .messages: return "Messages"
        case .findPeople: return "Find people"
        case .you: return "You"
        }
    }

    var systemImage: String {
        switch self {
        case .messages: return "bubble.left.and.bubble.right"
        case .findPeople: return "magnifyingglass"
        case .you: return "person.crop.circle"
        }
    }
}

struct PillTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button { selection = tab } label: {
                    VStack(spacing: Spacing.xs) {
                        Image(systemName: tab.systemImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: Metrics.tabIcon, height: Metrics.tabIcon)
                        Text(tab.title).font(Theme.tabLabel)
                    }
                    .foregroundStyle(selection == tab ? Theme.gold : Theme.text3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
            }
        }
        .frame(height: Metrics.tabBarHeight)
        .background(Capsule().fill(Theme.raise))
        .shadow(color: Theme.bg.opacity(0.6), radius: Spacing.l, y: Spacing.s)
    }
}
```

`Sources/App/DesignSystem/Controls.swift`:

```swift
import SwiftUI

struct IconButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: TypeScale.body, weight: .semibold))
                .foregroundStyle(Theme.gold)
                .frame(width: Metrics.iconButton, height: Metrics.iconButton)
                .background(Circle().fill(Theme.raise))
        }
        .buttonStyle(.plain)
    }
}

struct SearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.placeholder)
            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(Theme.placeholder))
                .foregroundStyle(Theme.text)
                .tint(Theme.gold)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
        .font(Theme.body)
        .padding(.horizontal, Spacing.m)
        .frame(height: Metrics.searchHeight)
        .background(RoundedRectangle(cornerRadius: Radius.search, style: .continuous).fill(Theme.card))
    }
}

struct GoldCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.name)
            .foregroundStyle(Theme.goldInk)
            .padding(.horizontal, Spacing.xl)
            .frame(height: Metrics.inputControl)
            .background(Capsule().fill(Theme.gold))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(title.uppercased()).font(Theme.label).foregroundStyle(Theme.text3)
                .padding(.leading, Spacing.l)
            VStack(alignment: .leading, spacing: Spacing.m) { content }
                .padding(Spacing.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Theme.card))
        }
    }
}

struct ValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title).font(Theme.body).foregroundStyle(Theme.text)
            Spacer(minLength: Spacing.s)
            Text(value).font(Theme.preview).foregroundStyle(Theme.text2).lineLimit(1)
        }
    }
}
```

- [ ] **Step 3: Run the local suite** (sanity: package targets unaffected). Expected: all pass.

- [ ] **Step 4: Commit and build in CI**

```bash
git add project.yml Sources/App/DesignSystem
git commit -m "Add SwiftUI design system built from tokens"
```

Run the CI command. Expected: green. The old shell is still the running UI; the new components compile but are not shown yet.

---

### Task 6: Cache-first inbox screen

**Files:**
- Modify: `Sources/App/Web/InstagramSession.swift` (additive: web chat presentation)
- Create: `Sources/App/App/AppCache.swift`, `Sources/App/Inbox/InboxStore.swift`, `Sources/App/Inbox/SampleData.swift`, `Sources/App/Inbox/StoriesRow.swift`, `Sources/App/Inbox/InboxView.swift`

**Interfaces:**
- Consumes: `DiskCache`, `InboxLoader`, `InboxSource`, `InboxSearch`, `RelativeTimestamp`, `ThreadSummary` (Tasks 3–4); `ChatCard`, `StoryCircle`, `SearchField`, `IconButton`, `GoldCapsuleButtonStyle`, `Theme`, `Metrics`, `Spacing` (Task 5).
- Produces: `InstagramSession.webChatPresented: Bool` (`@Published`, settable) and `InstagramSession.openWebChat()`; `enum AppCache { static func make() -> DiskCache }`; `@MainActor final class InboxStore: ObservableObject` with `init(cache: DiskCache)`, `@Published private(set) var snapshot: InboxSnapshot?`, `@Published private(set) var lastError: String?`, `@Published var showsSampleData: Bool`, `func reload() async`, `func clearAll()`; `InboxView()` (reads `InboxStore` and `InstagramSession` from the environment).

- [ ] **Step 1: Add web-chat presentation to the existing session** — in `Sources/App/Web/InstagramSession.swift`, below `@Published private(set) var authState …` add:

```swift
    /// Drives the full-screen web chat fallback.
    @Published var webChatPresented = false
```

and below `func loadInbox()` add:

```swift
    func openWebChat() {
        loadInbox()
        webChatPresented = true
    }
```

- [ ] **Step 2: Create the inbox files**

`Sources/App/App/AppCache.swift`:

```swift
import Foundation

enum AppCache {
    static func make() -> DiskCache {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        if let cache = try? DiskCache(directory: base.appendingPathComponent("Cache", isDirectory: true)) {
            return cache
        }
        // Application Support is always creatable in practice; tmp keeps the app launching if it isn't.
        return try! DiskCache(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("Cache", isDirectory: true))
    }
}
```

`Sources/App/Inbox/SampleData.swift`:

```swift
import Foundation

/// Fake chats for checking the design on the phone before the live inbox exists.
/// Stored under a separate cache key so it can never mix with real data.
struct SampleInboxSource: InboxSource {
    func fetchInbox() async throws -> InboxSnapshot {
        let now = Date()
        func ago(_ minutes: Double) -> Date { now.addingTimeInterval(-minutes * 60) }
        return InboxSnapshot(threads: [
            ThreadSummary(id: "s1", title: "Ana", avatarURL: nil, lastMessagePreview: "sent you a reel",
                          lastActivity: ago(4), isUnread: true, isPinned: false),
            ThreadSummary(id: "s2", title: "Luka", avatarURL: nil, lastMessagePreview: "Voice message · 0:14",
                          lastActivity: ago(41), isUnread: false, isPinned: false),
            ThreadSummary(id: "s3", title: "Maja", avatarURL: nil, lastMessagePreview: "haha ok see you there",
                          lastActivity: ago(60 * 26), isUnread: false, isPinned: false),
            ThreadSummary(id: "s4", title: "Tim", avatarURL: nil, lastMessagePreview: "You: sent a photo",
                          lastActivity: ago(60 * 50), isUnread: false, isPinned: false),
            ThreadSummary(id: "s5", title: "Nika", avatarURL: nil, lastMessagePreview: "ok 👍",
                          lastActivity: ago(60 * 24 * 9), isUnread: false, isPinned: true),
        ], fetchedAt: now)
    }
}

enum SampleStories {
    static let items: [StoryRowItem] = [
        StoryRowItem(id: "s1", name: "Ana", avatarURL: nil, kind: .unseen),
        StoryRowItem(id: "s2", name: "Luka", avatarURL: nil, kind: .unseen),
        StoryRowItem(id: "s3", name: "Maja", avatarURL: nil, kind: .seen),
        StoryRowItem(id: "s4", name: "Tim", avatarURL: nil, kind: .seen),
    ]
}
```

`Sources/App/Inbox/StoriesRow.swift`:

```swift
import SwiftUI

struct StoryRowItem: Identifiable {
    let id: String
    let name: String
    let avatarURL: URL?
    let kind: StoryCircle.Kind
}

/// Own circle first (posting arrives in milestone 5), then followed accounts' stories.
struct StoriesRow: View {
    let items: [StoryRowItem]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: Metrics.storyGap) {
                StoryCircle(name: "You", avatarURL: nil, kind: .own)
                ForEach(items) { item in
                    StoryCircle(name: item.name, avatarURL: item.avatarURL, kind: item.kind)
                }
            }
            .padding(.horizontal, Spacing.screenEdge)
        }
    }
}
```

`Sources/App/Inbox/InboxStore.swift`:

```swift
import Foundation

/// Inbox state for the Messages screen. Shows the cache instantly, then refreshes.
/// Until the live InstagramClient exists (next plan), only the sample source is connected.
@MainActor
final class InboxStore: ObservableObject {
    private static let sampleKey = "showsSampleInbox"

    @Published private(set) var snapshot: InboxSnapshot?
    @Published private(set) var lastError: String?
    @Published var showsSampleData: Bool {
        didSet {
            UserDefaults.standard.set(showsSampleData, forKey: Self.sampleKey)
            Task { await reload() }
        }
    }

    private let cache: DiskCache

    init(cache: DiskCache) {
        self.cache = cache
        showsSampleData = UserDefaults.standard.bool(forKey: Self.sampleKey)
        snapshot = loader?.cached()
    }

    private var loader: InboxLoader? {
        showsSampleData ? InboxLoader(cache: cache, source: SampleInboxSource(), cacheKey: "inbox-sample") : nil
    }

    func reload() async {
        guard let loader else {
            snapshot = nil
            return
        }
        if snapshot == nil { snapshot = loader.cached() }
        do {
            snapshot = try await loader.refresh()
            lastError = nil
        } catch {
            // Never surface response bodies or identifiers.
            lastError = "Couldn't refresh"
        }
    }

    /// Used by Reset Session: removes every cached file.
    func clearAll() {
        try? cache.removeAll()
        snapshot = nil
    }
}
```

`Sources/App/Inbox/InboxView.swift`:

```swift
import SwiftUI

struct InboxView: View {
    @EnvironmentObject private var inbox: InboxStore
    @EnvironmentObject private var session: InstagramSession
    @State private var query = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                SearchField(text: $query, placeholder: "Search chats")
                    .padding(.horizontal, Spacing.screenEdge)
                    .padding(.top, Spacing.m)
                StoriesRow(items: inbox.showsSampleData ? SampleStories.items : [])
                    .padding(.top, Spacing.l)
                    .padding(.bottom, Spacing.m)
                threads
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .refreshable { await inbox.reload() }
        .task { await inbox.reload() }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("Messages").font(Theme.largeTitle).foregroundStyle(Theme.text)
            Spacer()
            // New message opens web chat until native chat lands (milestone 2).
            IconButton(systemImage: "square.and.pencil") { session.openWebChat() }
        }
        .padding(.horizontal, Spacing.screenEdge)
        .padding(.top, Spacing.s)
    }

    @ViewBuilder private var threads: some View {
        let all = inbox.snapshot?.threads ?? []
        let shown = InboxSearch.filter(all, query: query)
        if all.isEmpty {
            emptyState
        } else if shown.isEmpty {
            Text("No chats match “\(query)”")
                .font(Theme.preview).foregroundStyle(Theme.text2)
                .frame(maxWidth: .infinity)
                .padding(.top, Spacing.xxl)
        } else {
            let now = Date()
            LazyVStack(spacing: Metrics.cardGap) {
                ForEach(shown) { thread in
                    Button { session.openWebChat() } label: {
                        ChatCard(thread: thread,
                                 timestamp: RelativeTimestamp.string(for: thread.lastActivity, now: now,
                                                                     calendar: .current, locale: .current))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.screenEdge)
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.m) {
            Text("No chats here yet").font(Theme.name).foregroundStyle(Theme.text)
            Text("The native inbox connects in the next build. Until then, use web chat — or turn on the sample inbox in You to preview the design.")
                .font(Theme.preview)
                .foregroundStyle(Theme.text2)
                .multilineTextAlignment(.center)
            Button("Open web chat") { session.openWebChat() }
                .buttonStyle(GoldCapsuleButtonStyle())
                .padding(.top, Spacing.s)
        }
        .padding(Spacing.xxl)
        .frame(maxWidth: .infinity)
    }
}
```

- [ ] **Step 3: Commit and build in CI**

```bash
git add Sources/App/App/AppCache.swift Sources/App/Inbox Sources/App/Web/InstagramSession.swift
git commit -m "Add cache-first inbox screen with sample data"
```

Run the CI command. Expected: green (InboxView is not shown yet; Task 7 wires it in).

---

### Task 7: New shell — login sheet, three tabs, You, web chat

**Files:**
- Move: `Sources/App/Web/InstagramSession.swift` → `Sources/App/Session/InstagramSession.swift`; `Sources/App/Web/InstagramWebView.swift` → `Sources/App/WebChat/InstagramWebView.swift`; `Sources/App/Web/NavigationGuard.swift` → `Sources/App/WebChat/NavigationGuard.swift`
- Rewrite: `Sources/App/Session/InstagramSession.swift`, `Sources/App/App/RootView.swift`, `Sources/App/App/InstagramUtilityApp.swift`
- Modify: `Sources/App/WebChat/NavigationGuard.swift` (add microphone permission)
- Create: `Sources/App/Session/LoginView.swift`, `Sources/App/WebChat/WebChatView.swift`, `Sources/App/FindPeople/FindPeopleView.swift`, `Sources/App/You/YouView.swift`
- Delete: `Sources/App/App/MessagesView.swift`, `Sources/App/Settings/SettingsView.swift`

**Interfaces:**
- Consumes: `InboxView`, `InboxStore`, `AppCache` (Task 6); design system (Task 5); `DiagnosticsStore`, `NavigationGuard`, `InstagramWebView`, `InstagramRoutePolicy` (POC, unchanged APIs).
- Produces: `InstagramSession` (NSObject, ObservableObject, WKHTTPCookieStoreObserver) with `authState`, `webChatPresented`, `diagnostics`, `webView`, `start() async`, `openWebChat()`, `loadInbox()`, `backToConversation()`, `refreshAuthState() async`, `resetSession() async`.

- [ ] **Step 1: Move files with git**

```bash
mkdir -p Sources/App/Session Sources/App/WebChat Sources/App/FindPeople Sources/App/You
git mv Sources/App/Web/InstagramSession.swift Sources/App/Session/InstagramSession.swift
git mv Sources/App/Web/InstagramWebView.swift Sources/App/WebChat/InstagramWebView.swift
git mv Sources/App/Web/NavigationGuard.swift Sources/App/WebChat/NavigationGuard.swift
git rm -q Sources/App/App/MessagesView.swift Sources/App/Settings/SettingsView.swift
```

- [ ] **Step 2: Rewrite `Sources/App/Session/InstagramSession.swift`**

```swift
import Foundation
import WebKit

enum AuthenticationState: String {
    case unknown = "Unknown"
    case loggedOut = "Logged out"
    case authenticated = "Logged in"
}

/// Owns the one WKWebView that holds the Instagram login (persistent data store, so the session
/// survives restarts). Credentials are typed into Instagram's own page; this class never sees them.
/// The same web view backs the login sheet and the web chat fallback — never both at once.
@MainActor
final class InstagramSession: NSObject, ObservableObject, WKHTTPCookieStoreObserver {
    @Published private(set) var authState: AuthenticationState = .unknown
    @Published var webChatPresented = false
    let diagnostics = DiagnosticsStore()
    let webView: WKWebView
    private var navigationGuard: NavigationGuard?
    private var started = false

    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = .all
        // Present as mobile Safari so Instagram serves its normal mobile website.
        config.applicationNameForUserAgent = "Version/17.0 Mobile/15E148 Safari/604.1"
        webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = false
        webView.isOpaque = false
        webView.backgroundColor = .black
        super.init()
        navigationGuard = NavigationGuard(webView: webView, diagnostics: diagnostics) { [weak self] in
            Task { await self?.refreshAuthState() }
        }
        // Login completes inside Instagram's single-page app without a full page load, so watch cookies.
        webView.configuration.websiteDataStore.httpCookieStore.add(self)
    }

    /// Called once at launch. Shows the login page only if there is no session.
    func start() async {
        guard !started else { return }
        started = true
        await refreshAuthState()
        if authState == .loggedOut {
            webView.load(URLRequest(url: InstagramRoutePolicy.loginURL))
        }
    }

    func openWebChat() {
        loadInbox()
        webChatPresented = true
    }

    func loadInbox() {
        webView.load(URLRequest(url: InstagramRoutePolicy.inboxURL))
    }

    /// Returns to the last conversation (used to leave a DM-media page in web chat).
    func backToConversation() {
        navigationGuard?.returnToLastDirect()
    }

    /// Only checks that a session cookie exists (by name); the value is never stored, shown or logged.
    func refreshAuthState() async {
        let cookies: [HTTPCookie] = await withCheckedContinuation { cont in
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cont.resume(returning: $0) }
        }
        let has = cookies.contains { $0.domain.hasSuffix("instagram.com") && $0.name == "sessionid" && !$0.value.isEmpty }
        authState = has ? .authenticated : .loggedOut
    }

    nonisolated func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        Task { @MainActor in await self.refreshAuthState() }
    }

    /// Deliberate, user-confirmed logout: removes Instagram/Facebook web data only.
    func resetSession() async {
        let store = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        let records: [WKWebsiteDataRecord] = await withCheckedContinuation { cont in
            store.fetchDataRecords(ofTypes: types) { cont.resume(returning: $0) }
        }
        let needles = ["instagram", "facebook", "fbcdn"]
        let targets = records.filter { r in needles.contains { r.displayName.lowercased().contains($0) } }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            store.removeData(ofTypes: types, for: targets) { cont.resume() }
        }
        authState = .loggedOut
        navigationGuard?.reset()
        webView.load(URLRequest(url: InstagramRoutePolicy.loginURL))
    }
}
```

- [ ] **Step 3: Allow the microphone for Instagram in web chat** — in `Sources/App/WebChat/NavigationGuard.swift`, add this method inside the `// MARK: - WKUIDelegate` section, after `createWebViewWith`:

```swift
    /// Voice messages in web chat need the microphone. Only Instagram may ask; iOS still shows its prompt.
    func webView(_ webView: WKWebView,
                 requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo,
                 type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(origin.host.hasSuffix("instagram.com") ? .prompt : .deny)
    }
```

- [ ] **Step 4: Create the screens**

`Sources/App/Session/LoginView.swift`:

```swift
import SwiftUI

/// Instagram's own login page, shown whenever there is no session. Cannot be swiped away.
struct LoginView: View {
    @EnvironmentObject private var session: InstagramSession

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: Spacing.xs) {
                Text("Log in to Instagram").font(Theme.name).foregroundStyle(Theme.text)
                Text("This is Instagram's own page. Your password goes only to Instagram.")
                    .font(Theme.label)
                    .foregroundStyle(Theme.text2)
                    .multilineTextAlignment(.center)
            }
            .padding(Spacing.l)
            InstagramWebView(webView: session.webView)
        }
        .background(Theme.bg)
    }
}
```

`Sources/App/WebChat/WebChatView.swift`:

```swift
import SwiftUI

/// Instagram's web chat as a full-screen fallback. Full screen means the tab bar can never cover Send.
struct WebChatView: View {
    @EnvironmentObject private var session: InstagramSession
    @EnvironmentObject private var diagnostics: DiagnosticsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            // No .ignoresSafeArea here. The POC's `.ignoresSafeArea(edges: .bottom)` also ignored the
            // keyboard region, which is why the message field ended up under the keyboard.
            InstagramWebView(webView: session.webView)
                .navigationTitle("Web chat")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if diagnostics.currentCategory == .dmMediaAllowedOnce {
                            Button("Back to chat") { session.backToConversation() }
                        } else {
                            Button("Inbox") { session.loadInbox() }
                        }
                    }
                }
                .toolbarBackground(Theme.bg, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
        .tint(Theme.gold)
    }
}
```

`Sources/App/FindPeople/FindPeopleView.swift`:

```swift
import SwiftUI

/// Search and profiles arrive in milestone 6 (spec §8).
struct FindPeopleView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Find people").font(Theme.largeTitle).foregroundStyle(Theme.text)
            Text("Search, profiles and following arrive in a later build.")
                .font(Theme.preview)
                .foregroundStyle(Theme.text2)
            Spacer()
        }
        .padding(.horizontal, Spacing.screenEdge)
        .padding(.top, Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

`Sources/App/You/YouView.swift`:

```swift
import SwiftUI

struct YouView: View {
    @EnvironmentObject private var session: InstagramSession
    @EnvironmentObject private var inbox: InboxStore
    @EnvironmentObject private var diagnostics: DiagnosticsStore
    @State private var confirmReset = false

    private var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(v) (\(b))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                Text("You").font(Theme.largeTitle).foregroundStyle(Theme.text)
                    .padding(.top, Spacing.s)

                SettingsSection(title: "Web chat") {
                    Button("Open web chat") { session.openWebChat() }
                        .font(Theme.body)
                        .foregroundStyle(Theme.gold)
                }

                SettingsSection(title: "Preview") {
                    Toggle("Show sample inbox", isOn: $inbox.showsSampleData)
                        .font(Theme.body)
                        .foregroundStyle(Theme.text)
                        .tint(Theme.gold)
                }

                SettingsSection(title: "Diagnostics") {
                    ValueRow(title: "Version", value: version)
                    ValueRow(title: "Session", value: session.authState.rawValue)
                    ValueRow(title: "Web host", value: diagnostics.currentHost)
                    ValueRow(title: "Route", value: diagnostics.currentCategory?.rawValue ?? "-")
                    ValueRow(title: "Blocked navigations", value: String(diagnostics.blockedCount))
                    ValueRow(title: "Last blocked", value: diagnostics.lastBlockedSurface?.rawValue ?? "-")
                    ValueRow(title: "Inbox refresh", value: inbox.lastError ?? "OK")
                }

                SettingsSection(title: "Account") {
                    Button("Reset Instagram Session", role: .destructive) { confirmReset = true }
                        .font(Theme.body)
                    Text("Signs you out and deletes everything this app stored.")
                        .font(Theme.label)
                        .foregroundStyle(Theme.text3)
                }
            }
            .padding(.horizontal, Spacing.screenEdge)
        }
        .confirmationDialog("Reset Instagram session?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset and sign out", role: .destructive) {
                Task {
                    await session.resetSession()
                    inbox.clearAll()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .task { await session.refreshAuthState() }
    }
}
```

`Sources/App/App/RootView.swift`:

```swift
import SwiftUI

/// App shell: three tabs in a floating pill, login sheet when signed out, web chat as a full-screen cover.
struct RootView: View {
    @EnvironmentObject private var session: InstagramSession
    @State private var tab: AppTab = .messages

    private var loginRequired: Binding<Bool> {
        Binding(get: { session.authState == .loggedOut }, set: { _ in })
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            screen
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Keep the last row scrollable above the floating bar.
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: Metrics.tabBarHeight + Spacing.s)
                }
            VStack {
                Spacer()
                PillTabBar(selection: $tab)
                    .padding(.horizontal, Metrics.tabBarSide)
                    .padding(.bottom, Metrics.tabBarBottom)
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .ignoresSafeArea(.keyboard)
        }
        .preferredColorScheme(.dark)
        .tint(Theme.gold)
        .sheet(isPresented: loginRequired) {
            LoginView().interactiveDismissDisabled()
        }
        .fullScreenCover(isPresented: $session.webChatPresented) {
            WebChatView()
        }
        .task { await session.start() }
    }

    @ViewBuilder private var screen: some View {
        switch tab {
        case .messages: InboxView()
        case .findPeople: FindPeopleView()
        case .you: YouView()
        }
    }
}
```

`Sources/App/App/InstagramUtilityApp.swift`:

```swift
import SwiftUI

@main
struct InstagramUtilityApp: App {
    @StateObject private var session = InstagramSession()
    @StateObject private var inbox = InboxStore(cache: AppCache.make())

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(session.diagnostics)
                .environmentObject(inbox)
        }
    }
}
```

Note: `.fullScreenCover` and `.sheet` both need the shared `webView`; they never show together because the login sheet only appears when logged out and web chat is opened by the user while logged in. If the session expires while web chat is open, Instagram's login page appears inside web chat (auth routes are allowed by the route policy).

- [ ] **Step 5: Confirm the POC folders are gone**

Run: `ls Sources/App` — expected: `App DesignSystem Diagnostics FindPeople Inbox Session WebChat You` (no `Web`, no `Settings`).

- [ ] **Step 6: Run the local suite** — all tests pass (package targets unchanged).

- [ ] **Step 7: Commit and build in CI**

```bash
git add -A Sources/App
git commit -m "Replace POC shell with three-tab app, login sheet and fixed web chat"
```

Run the CI command. Expected: green, IPA artifact uploaded.

---

### Task 8: Docs, device checklist, handoff

**Files:**
- Rewrite: `AGENTS.md`, `NEXT_SESSION_HANDOFF.md`
- Modify: `README.md`, `docs/IPHONE_INSTALL.md` (section 4)

- [ ] **Step 1: Rewrite `AGENTS.md`**

```markdown
# AGENTS.md — Instagram Utility (iOS)

Read this, then the spec: `docs/superpowers/specs/2026-10-05-instagram-utility-v1-design.md`.

## Product
A fast native iPhone app for Instagram communication: DMs, stories, story posting, finding people.
**No feed, Explore or Reels — the code for them must not exist.** Content is only ever shown from a
profile the user deliberately opened or something someone sent them.

## Hard rules
1. €0. No paid Apple program, server, hosting, CI or dependency.
2. No backend. The app works alone on the phone.
3. Data comes from the internal endpoints instagram.com itself uses, called from the user's own session
   on the phone (spec §2). Never imitate the official app's device signatures. Respect the request
   budget in spec §5.
4. Never handle the password. Login is Instagram's own page in `InstagramSession`'s web view.
5. Never log, display or commit cookies, session ids, tokens or user data. Fixtures use fake names.
6. Every colour/size in views comes from `Theme` / `Spacing` / `Metrics` / `Radius` / `TypeScale`.
   No raw numbers or hex in views. Token tests fail the build if the system drifts.

## Where things go
| Concern | Location |
|---|---|
| Colours, spacing, type, radii, sizes (+ tests) | `Sources/DesignTokens/`, `Tests/DesignTokensTests/` |
| Testable app logic (models, ordering, search, cache) | `Sources/Core/`, `Tests/CoreTests/` |
| Web-chat route firewall | `Sources/RoutePolicy/`, `Tests/RoutePolicyTests/` |
| SwiftUI components | `Sources/App/DesignSystem/` |
| Screens | `Sources/App/<Feature>/` (Inbox, FindPeople, You, WebChat, Session) |
| Login / session web view | `Sources/App/Session/InstagramSession.swift` |
| App shell and tabs | `Sources/App/App/RootView.swift`, `DesignSystem/PillTabBar.swift` |

Example: "add an unread-only toggle to Messages" → filtering rule in `Sources/Core/InboxSearch.swift`
(with a test), toggle UI in `Sources/App/Inbox/InboxView.swift`.

## Build & test
- `swift test` runs every pure-logic test (Linux or macOS). Locally on this Windows machine use the WSL
  command in `docs/superpowers/plans/2026-10-05-m1-foundation.md` ("How to run things").
- The iOS app builds only in CI (`.github/workflows/build-ios.yml`): `swift test` → XcodeGen → unsigned
  Release build → `InstagramUtility-unsigned.ipa` artifact. Install with SideStore (`docs/IPHONE_INSTALL.md`).
- SwiftUI views have no unit tests; each milestone ends with the owner's on-device checklist.

## Current state
Milestone 1 (foundation). Inbox shows sample data only; the live inbox and native chat come next,
after the endpoint-discovery session. Chats open in web chat for now.
```

- [ ] **Step 2: Update `README.md`** — replace the "Status" paragraph with:

```markdown
Status: v1 in progress — milestone 1 (foundation: design system, login, three-tab shell, cache-first
inbox with sample data, web chat fallback). Live inbox and native chat are next.
Spec: `docs/superpowers/specs/2026-10-05-instagram-utility-v1-design.md`.
```

and replace the "How it works" paragraph with:

```markdown
## How it works
Native SwiftUI screens styled by one token system (Espresso v3). A hidden persistent `WKWebView` holds
your genuine Instagram login on the device. Web chat (Instagram's own page, behind a route firewall)
is the fallback. No backend.
```

- [ ] **Step 3: Replace section 4 of `docs/IPHONE_INSTALL.md`** with:

```markdown
## 4. Milestone 1 checklist (on the iPhone)
1. Install the new IPA in SideStore (it replaces the POC; your login may need to be redone once).
2. First launch: a sheet with Instagram's real login page. Log in (2FA as normal). The sheet closes.
3. Messages tab: dark Espresso design, "No chats here yet" and an Open web chat button.
4. Force-quit, reopen. **No login sheet** (session persisted — the POC's untested step 2).
   If the sheet flashes and then closes by itself, note it — that is the cookie store warming up.
5. You → Preview → turn on **Show sample inbox**. Messages shows 5 sample chats and a stories row.
   Check the look: spacing, sizes, contrast. Note anything that feels off and in which direction.
6. Type "lu" in Search chats → only Luka remains.
7. Tap a chat → web chat opens full screen. Open a conversation, tap the message field:
   **the field and Send sit above the keyboard.** Close the keyboard: **Send is visible** (no tab bar).
8. In web chat, record a voice message (iOS asks for the microphone the first time).
9. Done → back in the app. You → Reset Instagram Session → confirm → the login sheet appears.
Known and expected: in web chat you can still swipe from a shared reel to other reels. That is fixed
by the native viewer in milestone 3; web chat is only the fallback.
```

- [ ] **Step 4: Rewrite `NEXT_SESSION_HANDOFF.md`**

```markdown
# Handoff — Instagram Utility

## State (update the date and run id when you finish)
- Milestone 1 (foundation) implemented per `docs/superpowers/plans/2026-10-05-m1-foundation.md`.
- CI: green on main; artifact `InstagramUtility-unsigned-ipa`.
- Device checklist (`docs/IPHONE_INSTALL.md` §4): not yet run by the owner.

## Next
1. Owner runs the milestone 1 checklist on the iPhone 13 and reports.
2. Endpoint-discovery session: owner logs into instagram.com in the desktop app's browser pane and uses
   DMs (inbox, a thread, sending text/photo/voice). Claude reads request names and response shapes only.
3. Write the next plan: InstagramClient (+ rate limiter) → live inbox → native chat (milestone 2).
```

- [ ] **Step 5: Commit, push, confirm CI green**

```bash
git add AGENTS.md README.md docs/IPHONE_INSTALL.md NEXT_SESSION_HANDOFF.md
git commit -m "Update docs and device checklist for milestone 1"
```

Run the CI command. Expected: green. Record the run id and artifact size in `NEXT_SESSION_HANDOFF.md`, commit, push.

- [ ] **Step 6: Report to the owner** — give the CI run URL, the artifact name, and the checklist path as a full `C:\Users\stepa\Desktop\AI\active\instagram-utility-ios\docs\IPHONE_INSTALL.md` path (or open it with the editor tool). State plainly that nothing in this milestone has been verified on the device yet.
