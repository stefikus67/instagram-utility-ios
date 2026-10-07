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
        XCTAssertEqual(c("https://www.instagram.com/Explore/"), .blocked)
    }

    // M3: search
    func testExploreSearchAllowed() {
        XCTAssertEqual(c("https://www.instagram.com/explore/search/"), .searchAllowed)
        XCTAssertEqual(c("https://www.instagram.com/explore/search/keyword/?q=x"), .searchAllowed)
    }

    func testExploreNonSearchBlocked() {
        XCTAssertEqual(c("https://www.instagram.com/explore/"), .blocked)
        XCTAssertEqual(c("https://www.instagram.com/explore/tags/cats/"), .blocked)
        XCTAssertEqual(c("https://www.instagram.com/explore/people/"), .blocked)
    }

    func testProfileFromSearchAllowed() {
        XCTAssertEqual(c("https://www.instagram.com/someone/", from: "https://www.instagram.com/explore/search/"), .profileAllowed)
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

    // M5: own-account pages (edit profile, settings, archive, your activity)
    func testOwnAccountPagesAllowed() {
        XCTAssertEqual(c("https://www.instagram.com/accounts/edit/"), .settingsAllowed)
        XCTAssertEqual(c("https://www.instagram.com/accounts/privacy_and_security/"), .settingsAllowed)
        XCTAssertEqual(c("https://www.instagram.com/accounts/notifications/"), .settingsAllowed)
        XCTAssertEqual(c("https://www.instagram.com/archive/stories/"), .settingsAllowed)
        XCTAssertEqual(c("https://www.instagram.com/your_activity/interactions/likes/"), .settingsAllowed)
        // Auth pages keep winning over settings.
        XCTAssertEqual(c("https://www.instagram.com/accounts/login/"), .authAllowed)
    }

    func testOwnAccountPagesAreValidMediaSources() {
        XCTAssertEqual(c("https://www.instagram.com/p/ABC123/", from: "https://www.instagram.com/archive/stories/"), .mediaAllowed)
    }

    func testArchiveAndActivityAreNotUsernames() {
        XCTAssertNil(InstagramRoutePolicy.profileURL(username: "archive"))
        XCTAssertNil(InstagramRoutePolicy.profileURL(username: "your_activity"))
    }

    // M2: profiles
    func testProfileAllowed() {
        XCTAssertEqual(c("https://www.instagram.com/someone/"), .profileAllowed)
        XCTAssertEqual(c("https://www.instagram.com/someone/reels/"), .profileAllowed)   // their own reels grid
        XCTAssertEqual(c("https://www.instagram.com/someone/tagged/"), .profileAllowed)
    }
    func testFeedAndDiscoveryStillBlocked() {
        XCTAssertEqual(c("https://www.instagram.com/"), .blocked)
        XCTAssertEqual(c("https://www.instagram.com/explore/"), .blocked)
        XCTAssertEqual(c("https://www.instagram.com/reels/"), .blocked)            // global reels feed
    }
    // M2: stories
    func testStoriesAllowed() {
        XCTAssertEqual(c("https://www.instagram.com/stories/someone/"), .storiesAllowed)
        XCTAssertEqual(c("https://www.instagram.com/stories/someone/123/"), .storiesAllowed)
    }
    // M2: story creation / posting
    func testCreateAllowed() {
        XCTAssertEqual(c("https://www.instagram.com/create/story/"), .createAllowed)
        XCTAssertEqual(c("https://www.instagram.com/create/details/"), .createAllowed)
    }
    // M2: media reachable from profile and stories, not just DMs
    func testMediaFromProfile() {
        XCTAssertEqual(c("https://www.instagram.com/p/AAA/", from: "https://www.instagram.com/someone/"), .mediaAllowed)
        XCTAssertEqual(c("https://www.instagram.com/reel/AAA/", from: "https://www.instagram.com/someone/"), .mediaAllowed)
    }
    func testMediaFromStories() {
        XCTAssertEqual(c("https://www.instagram.com/p/AAA/", from: "https://www.instagram.com/stories/someone/1/"), .mediaAllowed)
    }
    func testMediaFromDirectStillAllowed() {
        XCTAssertEqual(c("https://www.instagram.com/reel/AAA/", from: dm), .mediaAllowed)
    }
    func testMediaFromNowhereBlocked() {
        XCTAssertEqual(c("https://www.instagram.com/reel/AAA/"), .blocked)
        XCTAssertEqual(c("https://www.instagram.com/reel/AAA/", from: "https://www.instagram.com/accounts/login/"), .blocked)
    }
    func testMediaChainStillBlocked() {
        XCTAssertEqual(c("https://www.instagram.com/reel/BBB/", from: "https://www.instagram.com/reel/AAA/"), .blocked)
    }
    func testProfileIsAValidMediaSourceButDiscoveryIsNot() {
        // "/reels/" (feed) is never a valid source
        XCTAssertEqual(c("https://www.instagram.com/p/AAA/", from: "https://www.instagram.com/reels/"), .blocked)
    }

    // DM media
    func testMediaFromDirectAllowedOnce() {
        XCTAssertEqual(c("https://www.instagram.com/reel/ABC123/", from: dm), .mediaAllowed)
        XCTAssertEqual(c("https://www.instagram.com/p/ABC123/", from: dm), .mediaAllowed)
        XCTAssertEqual(c("https://www.instagram.com/someuser/reel/ABC123/", from: dm), .mediaAllowed)
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
        XCTAssertEqual(c("https://www.instagram.com/p/AAA/?img_index=2", from: first), .mediaAllowed)
    }

    func testMediaBackToDirectAllowed() {
        XCTAssertEqual(c(dm, from: "https://www.instagram.com/reel/AAA/"), .directAllowed)
    }

    // Unknown routes
    func testUnknownInstagramRoutesBlocked() {
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

    func testProfileURLBuildsAllowedProfiles() {
        XCTAssertEqual(InstagramRoutePolicy.profileURL(username: "Some.One_9")?.absoluteString, "https://www.instagram.com/some.one_9/")
        XCTAssertEqual(InstagramRoutePolicy.profileURL(username: "  @alice ")?.absoluteString, "https://www.instagram.com/alice/")
        XCTAssertEqual(InstagramRoutePolicy.classify(InstagramRoutePolicy.profileURL(username: "alice")!), .profileAllowed)
    }

    func testProfileURLRejectsBadOrReservedNames() {
        for bad in ["", "   ", "@", "a b", "a/b", "../explore", "name?x=1", "ünï", String(repeating: "a", count: 31),
                    "explore", "direct", "reels", "accounts", "p", "create", "stories"] {
            XCTAssertNil(InstagramRoutePolicy.profileURL(username: bad), "should reject \(bad)")
        }
    }

    func testCreateStoryURLIsAllowed() {
        XCTAssertEqual(InstagramRoutePolicy.classify(InstagramRoutePolicy.createStoryURL), .createAllowed)
    }

    func testAllowedFlag() {
        XCTAssertTrue(RouteCategory.directAllowed.isAllowedInApp)
        XCTAssertTrue(RouteCategory.authAllowed.isAllowedInApp)
        XCTAssertTrue(RouteCategory.profileAllowed.isAllowedInApp)
        XCTAssertTrue(RouteCategory.storiesAllowed.isAllowedInApp)
        XCTAssertTrue(RouteCategory.createAllowed.isAllowedInApp)
        XCTAssertTrue(RouteCategory.mediaAllowed.isAllowedInApp)
        XCTAssertTrue(RouteCategory.searchAllowed.isAllowedInApp)
        XCTAssertTrue(RouteCategory.settingsAllowed.isAllowedInApp)
        XCTAssertFalse(RouteCategory.blocked.isAllowedInApp)
        XCTAssertFalse(RouteCategory.external.isAllowedInApp)
    }
}
