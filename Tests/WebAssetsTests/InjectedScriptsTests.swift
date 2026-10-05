import XCTest
@testable import WebAssets

final class InjectedScriptsTests: XCTestCase {
    func testScriptsAreNonEmpty() {
        XCTAssertFalse(InjectedScripts.hideChromeCSS.isEmpty)
        XCTAssertFalse(InjectedScripts.routeGuardJS.isEmpty)
        XCTAssertFalse(InjectedScripts.reelLockJS.isEmpty)
        XCTAssertFalse(InjectedScripts.orientationFixJS.isEmpty)
        XCTAssertFalse(InjectedScripts.unreadToggleJS.isEmpty)
    }
    func testJSIsDefensivelyWrapped() {
        for js in [InjectedScripts.routeGuardJS, InjectedScripts.reelLockJS, InjectedScripts.orientationFixJS, InjectedScripts.unreadToggleJS] {
            XCTAssertTrue(js.contains("try"), "JS must be wrapped in try/catch")
            XCTAssertTrue(js.contains("(function"), "JS must be an IIFE to avoid polluting globals")
        }
    }
    func testOrientationFixOverridesOrientation() {
        XCTAssertTrue(InjectedScripts.orientationFixJS.contains("orientation"))
    }
    func testNoTokenOrCredentialAccess() {
        // Guardrail: injected JS must not touch cookies, localStorage auth, or fb_dtsg.
        for js in [InjectedScripts.routeGuardJS, InjectedScripts.reelLockJS, InjectedScripts.orientationFixJS, InjectedScripts.unreadToggleJS, InjectedScripts.hideChromeCSS] {
            for banned in ["document.cookie", "fb_dtsg", "sessionid", "localStorage", "XMLHttpRequest", "fetch("] {
                XCTAssertFalse(js.contains(banned), "injected asset must not reference \(banned)")
            }
        }
    }
    func testBridgeMessageNamesAreStable() {
        XCTAssertTrue(InjectedScripts.routeGuardJS.contains("iuBlocked"))
    }

    // Additional guardrails beyond the brief.
    func testJSEndsAsInvokedIIFE() {
        for js in [InjectedScripts.routeGuardJS, InjectedScripts.reelLockJS, InjectedScripts.orientationFixJS, InjectedScripts.unreadToggleJS] {
            XCTAssertTrue(js.hasPrefix("(function"), "JS must start with an IIFE")
            XCTAssertTrue(js.hasSuffix("})();"), "JS must end with an invoked IIFE")
            XCTAssertTrue(js.contains("catch"), "JS must contain a catch")
        }
    }
    func testNoPolling() {
        for js in [InjectedScripts.routeGuardJS, InjectedScripts.reelLockJS, InjectedScripts.orientationFixJS, InjectedScripts.unreadToggleJS] {
            XCTAssertFalse(js.contains("setInterval"), "no polling allowed")
        }
    }
    func testRouteAwareScriptsPatchHistory() {
        for js in [InjectedScripts.routeGuardJS, InjectedScripts.reelLockJS] {
            XCTAssertTrue(js.contains("pushState"))
            XCTAssertTrue(js.contains("replaceState"))
            XCTAssertTrue(js.contains("popstate"))
        }
    }
    func testRouteGuardBlocksExpectedPrefixes() {
        let js = InjectedScripts.routeGuardJS
        XCTAssertTrue(js.contains("/explore"))
        XCTAssertTrue(js.contains("/reels/"))
        XCTAssertTrue(js.contains("messageHandlers"))
    }
    func testReelLockTargetsReelAndPostPaths() {
        let js = InjectedScripts.reelLockJS
        XCTAssertTrue(js.contains("/reel/"))
        XCTAssertTrue(js.contains("/p/"))
        XCTAssertTrue(js.contains("wheel"))
        XCTAssertTrue(js.contains("touchmove"))
    }
    func testUnreadToggleExposesSetterAndAttribute() {
        XCTAssertTrue(InjectedScripts.unreadToggleJS.contains("__iuSetUnreadOnly"))
        XCTAssertTrue(InjectedScripts.unreadToggleJS.contains("data-iu-unread-only"))
        XCTAssertTrue(InjectedScripts.hideChromeCSS.contains("data-iu-unread-only"))
    }
    func testChromeCSSIsHideOnly() {
        let css = InjectedScripts.hideChromeCSS
        XCTAssertTrue(css.contains("display:none !important"))
        XCTAssertTrue(css.contains("menubar"))
        XCTAssertTrue(css.contains("/explore"))
        XCTAssertFalse(css.contains("<"), "CSS must not contain markup")
    }
    func testStartAndEndGroupings() {
        XCTAssertEqual(InjectedScripts.documentStart(), [InjectedScripts.orientationFixJS, InjectedScripts.routeGuardJS])
        XCTAssertEqual(InjectedScripts.documentEnd(), [InjectedScripts.reelLockJS, InjectedScripts.unreadToggleJS])
    }
}
