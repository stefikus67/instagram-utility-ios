import XCTest
@testable import RoutePolicy

final class InstagramHostTests: XCTestCase {
    func testAcceptsInstagramHosts() {
        XCTAssertTrue(InstagramHost.isInstagram("instagram.com"))
        XCTAssertTrue(InstagramHost.isInstagram("www.instagram.com"))
        XCTAssertTrue(InstagramHost.isInstagram(".instagram.com"))
        XCTAssertTrue(InstagramHost.isInstagram("WWW.Instagram.COM"))
    }

    func testRejectsLookalikes() {
        XCTAssertFalse(InstagramHost.isInstagram("evilinstagram.com"))
        XCTAssertFalse(InstagramHost.isInstagram("instagram.com.evil.com"))
        XCTAssertFalse(InstagramHost.isInstagram(""))
        XCTAssertFalse(InstagramHost.isInstagram("instagram.co"))
    }
}
