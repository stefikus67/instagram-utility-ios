import XCTest
@testable import WebAssets
#if canImport(JavaScriptCore)
import JavaScriptCore
#endif

final class InjectedScriptsTests: XCTestCase {
    func testScriptsAreNonEmpty() {
        XCTAssertFalse(InjectedScripts.hideChromeCSS.isEmpty)
        XCTAssertFalse(InjectedScripts.routeGuardJS.isEmpty)
        XCTAssertFalse(InjectedScripts.reelLockJS.isEmpty)
        XCTAssertFalse(InjectedScripts.orientationFixJS.isEmpty)
        XCTAssertFalse(InjectedScripts.ownProfileJS.isEmpty)
        XCTAssertFalse(InjectedScripts.composerJS.isEmpty)
    }
    func testJSIsDefensivelyWrapped() {
        for js in [InjectedScripts.routeGuardJS, InjectedScripts.reelLockJS, InjectedScripts.orientationFixJS, InjectedScripts.ownProfileJS, InjectedScripts.composerJS] {
            XCTAssertTrue(js.contains("try"), "JS must be wrapped in try/catch")
            XCTAssertTrue(js.contains("(function"), "JS must be an IIFE to avoid polluting globals")
        }
    }
    func testOrientationFixOverridesOrientation() {
        XCTAssertTrue(InjectedScripts.orientationFixJS.contains("orientation"))
    }
    func testNoTokenOrCredentialAccess() {
        // Guardrail: injected JS must not touch cookies, localStorage auth, or fb_dtsg.
        for js in [InjectedScripts.routeGuardJS, InjectedScripts.reelLockJS, InjectedScripts.orientationFixJS, InjectedScripts.ownProfileJS, InjectedScripts.hideChromeCSS] {
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
        for js in [InjectedScripts.routeGuardJS, InjectedScripts.reelLockJS, InjectedScripts.orientationFixJS, InjectedScripts.ownProfileJS, InjectedScripts.composerJS] {
            XCTAssertTrue(js.hasPrefix("(function"), "JS must start with an IIFE")
            XCTAssertTrue(js.hasSuffix("})();"), "JS must end with an invoked IIFE")
            XCTAssertTrue(js.contains("catch"), "JS must contain a catch")
        }
    }
    func testNoPolling() {
        for js in [InjectedScripts.routeGuardJS, InjectedScripts.reelLockJS, InjectedScripts.orientationFixJS, InjectedScripts.ownProfileJS, InjectedScripts.composerJS] {
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
    func testReelLockTargetsReelsOnlyAndExemptsScrollableContent() {
        let js = InjectedScripts.reelLockJS
        XCTAssertTrue(js.contains("'reel'"))
        XCTAssertFalse(js.contains("/p/"), "photo posts must never be scroll-locked")
        XCTAssertFalse(js.contains("data-iu-reel-lock"), "dead attribute write removed")
        XCTAssertTrue(js.contains("wheel"))
        XCTAssertTrue(js.contains("touchmove"))
        XCTAssertTrue(js.contains("dialog"), "dialogs (comment drawer) must be exempt")
        XCTAssertTrue(js.contains("scrollHeight"), "scrollable content must be exempt")
        XCTAssertTrue(js.contains("touches.length > 1"), "multi-touch (pinch-zoom) must pass through")
    }
    func testOwnProfileScriptReadsOnlyNavHrefOnInbox() {
        let js = InjectedScripts.ownProfileJS
        XCTAssertTrue(js.contains("iuOwnUsername"))
        XCTAssertTrue(js.contains("'/direct/'"), "must only report from the inbox")
        XCTAssertTrue(js.contains("menubar"))
        for banned in ["cookie", "localStorage", "fetch("] {
            XCTAssertFalse(js.contains(banned), "own-profile script must not reference \(banned)")
        }
    }
    func testComposerScriptClicksOnlyNewPostAndReportsToItsHandler() {
        let js = InjectedScripts.composerJS
        for needed in ["New post", "iuComposer", "data-iu-composer", "MutationObserver", "__iuStartComposer", "'opened'", "'notfound'"] {
            XCTAssertTrue(js.contains(needed), "composer script must contain \(needed)")
        }
        for banned in ["fetch(", "cookie", "localStorage", "XMLHttpRequest", "location.href", "location.assign", "location.replace"] {
            XCTAssertFalse(js.contains(banned), "composer script must not reference \(banned)")
        }
        XCTAssertEqual(js.components(separatedBy: ".click()").count - 1, 1, "exactly one click, on the + button")
        XCTAssertEqual(js.components(separatedBy: "setTimeout(").count - 1, 2, "debounce and give-up timers only")
    }
    func testComposerCSSOnlyHidesFeedUnderComposerAttribute() {
        let rules = InjectedScripts.hideChromeCSS.components(separatedBy: "\n").filter { $0.contains("data-iu-composer") && !$0.hasPrefix("/*") }
        XCTAssertEqual(rules.count, 2)
        for rule in rules {
            XCTAssertTrue(rule.hasPrefix("html[data-iu-composer] main "), "unscoped composer rule: \(rule)")
            XCTAssertTrue(rule.contains("visibility:hidden !important"))
        }
    }
    func testChromeCSSIsHideOnly() {
        let css = InjectedScripts.hideChromeCSS
        XCTAssertTrue(css.contains("display:none !important"))
        XCTAssertTrue(css.contains("menubar"))
        XCTAssertTrue(css.contains("/explore"))
        XCTAssertFalse(css.contains("<"), "CSS must not contain markup")
    }
    func testChromeCSSLinkRulesAreScopedToNavigation() {
        // Every explore/reels/home link selector must be prefixed by a navigation container.
        for line in InjectedScripts.hideChromeCSS.components(separatedBy: "\n") where line.contains("a[href") {
            XCTAssertTrue(line.contains(":is(nav, [role=\"navigation\"], [role=\"menubar\"]) a[href"),
                          "unscoped link rule: \(line)")
        }
    }
#if canImport(JavaScriptCore)
    /// Catches JS syntax errors that string-contains tests cannot. Runs on macOS CI only (no JSC on Linux).
    func testAllJSParsesAndRunsWithoutThrowing() {
        let ctx = JSContext()!
        var thrown: String?
        ctx.exceptionHandler = { _, e in thrown = e?.toString() }
        // Minimal stubs so the IIFEs can execute headless.
        ctx.evaluateScript("""
        var window = this;
        window.webkit = {messageHandlers:{iuBlocked:{postMessage:function(){}}}};
        var history = {pushState:function(){}, replaceState:function(){}};
        window.history = history;
        var location = {pathname:'/'};
        window.location = location;
        var document = {documentElement:null, body:null, addEventListener:function(){}, querySelector:function(){return null}, querySelectorAll:function(){return []}, createElement:function(){return {}}, head:{appendChild:function(){}}};
        var screen = {orientation:{}};
        window.screen = screen;
        window.addEventListener = function(){};
        window.dispatchEvent = function(){};
        var MutationObserver = function(){ this.observe = function(){}; this.disconnect = function(){}; };
        """)
        XCTAssertNil(thrown, "stub setup failed: \(thrown ?? "")")
        for js in InjectedScripts.documentStart() + InjectedScripts.documentEnd() + [InjectedScripts.styleInjectionJS()] {
            thrown = nil
            ctx.evaluateScript(js)
            XCTAssertNil(thrown, "JS threw or failed to parse: \(thrown ?? "")")
        }
    }
#endif

    func testStyleInjectionWrapsCSSAsJSONLiteral() {
        let js = InjectedScripts.styleInjectionJS()
        XCTAssertTrue(js.hasPrefix("(function(){try{"))
        XCTAssertTrue(js.hasSuffix("})();"))
        XCTAssertTrue(js.contains("iu-hide-chrome"))
        XCTAssertTrue(js.contains("div[role=\\\"menubar\\\"]"), "CSS quotes must be JSON-escaped")
        XCTAssertFalse(js.contains("fetch(") || js.contains("XMLHttpRequest"))
        // A raw newline in the CSS must not reach the JS string literal.
        XCTAssertFalse(InjectedScripts.styleInjectionJS(css: "a\nb").contains("a\nb"))
    }

    func testStartAndEndGroupings() {
        XCTAssertEqual(InjectedScripts.documentStart(), [InjectedScripts.orientationFixJS, InjectedScripts.routeGuardJS])
        XCTAssertEqual(InjectedScripts.documentEnd(), [InjectedScripts.reelLockJS, InjectedScripts.ownProfileJS, InjectedScripts.composerJS])
    }
}
