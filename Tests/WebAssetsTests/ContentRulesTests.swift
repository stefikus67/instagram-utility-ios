import XCTest
@testable import WebAssets

final class ContentRulesTests: XCTestCase {
    func testJSONIsValidArrayOfRules() throws {
        let data = Data(ContentRules.json().utf8)
        let obj = try JSONSerialization.jsonObject(with: data)
        let arr = try XCTUnwrap(obj as? [[String: Any]])
        XCTAssertFalse(arr.isEmpty)
        for rule in arr {
            let trigger = try XCTUnwrap(rule["trigger"] as? [String: Any])
            XCTAssertNotNil(trigger["url-filter"] as? String)
            let action = try XCTUnwrap(rule["action"] as? [String: Any])
            XCTAssertEqual(action["type"] as? String, "block")
        }
    }
    func testBlocksDiscoveryEndpoints() {
        let j = ContentRules.json()
        for needle in ["feed/timeline", "discover/web/explore_grid", "clips/discover", "discover/chaining"] {
            XCTAssertTrue(j.contains(needle), "rule list must block \(needle)")
        }
    }
    func testEveryURLFilterIsAValidRegex() throws {
        let data = Data(ContentRules.json().utf8)
        let arr = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        for rule in arr {
            let f = (rule["trigger"] as? [String: Any])?["url-filter"] as? String ?? ""
            XCTAssertNoThrow(try NSRegularExpression(pattern: f), "bad url-filter regex: \(f)")
        }
    }
    func testDoesNotBlockDirectOrGraphqlSend() {
        // The DM surface itself and message-send must never be blocked.
        let allowed = ["https://www.instagram.com/direct/inbox/", "https://i.instagram.com/api/v1/direct_v2/threads/broadcast/text/", "https://www.instagram.com/api/graphql"]
        for url in allowed {
            for p in (ContentRules.blockedURLPatterns + ContentRules.blockedResourcePrefixes) {
                XCTAssertNil(url.range(of: p, options: .regularExpression), "\(p) must not block \(url)")
            }
        }
    }
}
