import XCTest
@testable import RoutePolicy

final class InstagramRoutePolicyTests: XCTestCase {
    private func u(_ s: String) -> URL { URL(string: s)! }
    private func c(_ s: String, from: String? = nil) -> RouteCategory {
        InstagramRoutePolicy.classify(u(s), from: from.map(u))
    }
    private let dm = "https://www.instagram.com/direct/t/1234/"

    // Feed
    func testHomeFeedBlocked() {
        XCTAssertEqual(c("https://www.instagram.com/"), .blocked)
        XCTAssertEqual(c("https://www.instagram.com"), .blocked)
        XCTAssertEqual(c("https://www.instagram.com/?variant=following"), .blocked)
        XCTAssertEqual(c("https://m.instagram.com/"), .blocked)
    }

    // Explore
    func testExploreBlocked() {
        XCTAssertEqual(c("https://www.instagram.com/explore/"), .blocked)
        XCTAssertEqual(c("https://www.instagram.com/explore/tags/cats/"), .blocked)
        XCTAssertEqual(c("https://www.instagram.com/explore/search/"), .blocked)
        XCTAssertEqual(c("https://www.instagram.com/Explore/"), .blocked)
    }

    // Reels
    func testReelsFeedBlocked() {
        XCTAssertEqual(c("https://www.instagram.com/reels/"), .blocked)
        XCTAssertEqual(c("https://www.instagram.com/reels/ABC123/", from: dm), .blocked)
        XCTAssertEqual(c("https://www.instagram.com/reel/ABC123/audio/", from: dm), .blocked)
    }

    // Direct
    func testDirectRoutesAllowed() {
        XCTAssertEqual(c("https://www.instagram.com/direct/inbox/"), .directAllowed)
        XCTAssertEqual(c(dm), .directAllowed)
        XCTAssertEqual(c("https://www.instagram.com/direct/requests/"), .directAllowed)
        XCTAssertEqual(c("https://www.instagram.com/direct/inbox/?next=/explore/"), .directAllowed)
    }

    // Auth
    func testAuthRoutesAllowed() {
        XCTAssertEqual(c("https://www.instagram.com/accounts/login/"), .authAllowed)
        XCTAssertEqual(c("https://www.instagram.com/accounts/login/?next=%2Fdirect%2Finbox%2F"), .authAllowed)
        XCTAssertEqual(c("https://www.instagram.com/accounts/login/two_factor/"), .authAllowed)
        XCTAssertEqual(c("https://www.instagram.com/accounts/onetap/"), .authAllowed)
        XCTAssertEqual(c("https://www.instagram.com/challenge/12345/abc/"), .authAllowed)
        XCTAssertEqual(c("https://www.instagram.com/auth_platform/codeentry/"), .authAllowed)
        XCTAssertEqual(c("https://accountscenter.instagram.com/"), .authAllowed)
        XCTAssertEqual(c("about:blank"), .authAllowed)
    }

    func testNonAuthAccountsRoutesBlocked() {
        XCTAssertEqual(c("https://www.instagram.com/accounts/emailsignup/"), .blocked)
        XCTAssertEqual(c("https://www.instagram.com/accounts/logout/"), .blocked)
        XCTAssertEqual(c("https://www.instagram.com/accounts/"), .blocked)
    }

    // DM media
    func testMediaFromDirectAllowedOnce() {
        XCTAssertEqual(c("https://www.instagram.com/reel/ABC123/", from: dm), .dmMediaAllowedOnce)
        XCTAssertEqual(c("https://www.instagram.com/p/ABC123/", from: dm), .dmMediaAllowedOnce)
        XCTAssertEqual(c("https://www.instagram.com/someuser/reel/ABC123/", from: dm), .dmMediaAllowedOnce)
    }

    func testMediaWithoutDirectSourceBlocked() {
        XCTAssertEqual(c("https://www.instagram.com/reel/ABC123/"), .blocked)
        XCTAssertEqual(c("https://www.instagram.com/p/ABC123/", from: "https://www.instagram.com/accounts/login/"), .blocked)
    }

    func testMediaChainBlocked() {
        let first = "https://www.instagram.com/reel/AAA/"
        XCTAssertEqual(c("https://www.instagram.com/reel/BBB/", from: first), .blocked)
        XCTAssertEqual(c("https://www.instagram.com/p/CCC/", from: first), .blocked)
    }

    func testSameMediaQueryChangeAllowed() {
        let first = "https://www.instagram.com/p/AAA/"
        XCTAssertEqual(c("https://www.instagram.com/p/AAA/?img_index=2", from: first), .dmMediaAllowedOnce)
    }

    func testMediaBackToDirectAllowed() {
        XCTAssertEqual(c(dm, from: "https://www.instagram.com/reel/AAA/"), .directAllowed)
    }

    // Unknown routes
    func testUnknownInstagramRoutesBlocked() {
        XCTAssertEqual(c("https://www.instagram.com/someuser/"), .blocked)
        XCTAssertEqual(c("https://www.instagram.com/stories/someuser/123/", from: dm), .blocked)
        XCTAssertEqual(c("https://www.instagram.com/notifications/"), .blocked)
        XCTAssertEqual(c("https://www.instagram.com/foo/bar/baz/qux/"), .blocked)
    }

    // Evasion attempts
    func testPathTraversalAndDoubleSlash() {
        XCTAssertEqual(c("https://www.instagram.com/direct/../explore/"), .blocked)
        XCTAssertEqual(c("https://www.instagram.com//explore/"), .blocked)
        XCTAssertEqual(c("https://www.instagram.com/direct/%2e%2e/explore/"), .blocked)
        XCTAssertEqual(c("https://www.instagram.com/./direct/inbox/"), .directAllowed)
    }

    // External
    func testExternalUrls() {
        XCTAssertEqual(c("https://example.com/"), .external)
        XCTAssertEqual(c("https://l.instagram.com/?u=https%3A%2F%2Fexample.com"), .external)
        XCTAssertEqual(c("https://help.instagram.com/"), .external)
        XCTAssertEqual(c("https://www.instagram.com@evil.com/direct/inbox/"), .external)
        XCTAssertEqual(c("https://instagram.com.evil.com/direct/inbox/"), .external)
        XCTAssertEqual(c("mailto:a@b.com"), .external)
        XCTAssertEqual(c("tel:123"), .external)
    }

    // Diagnostics labels
    func testBlockedSurfaceLabels() {
        XCTAssertEqual(InstagramRoutePolicy.blockedSurface(for: u("https://www.instagram.com/")), .home)
        XCTAssertEqual(InstagramRoutePolicy.blockedSurface(for: u("https://www.instagram.com/explore/")), .explore)
        XCTAssertEqual(InstagramRoutePolicy.blockedSurface(for: u("https://www.instagram.com/reels/")), .reels)
        XCTAssertEqual(InstagramRoutePolicy.blockedSurface(for: u("https://www.instagram.com/stories/x/1/")), .stories)
        XCTAssertEqual(InstagramRoutePolicy.blockedSurface(for: u("https://www.instagram.com/reel/AAA/")), .mediaOutsideDirect)
        XCTAssertEqual(InstagramRoutePolicy.blockedSurface(for: u("https://www.instagram.com/someone/")), .profileOrOther)
    }

    func testAllowedFlag() {
        XCTAssertTrue(RouteCategory.directAllowed.isAllowedInApp)
        XCTAssertTrue(RouteCategory.authAllowed.isAllowedInApp)
        XCTAssertTrue(RouteCategory.dmMediaAllowedOnce.isAllowedInApp)
        XCTAssertFalse(RouteCategory.blocked.isAllowedInApp)
        XCTAssertFalse(RouteCategory.external.isAllowedInApp)
    }
}
