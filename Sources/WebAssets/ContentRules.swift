import Foundation

/// A WKContentRuleList source that blocks Instagram's feed/Explore/Reels/ads/tracking requests at the
/// network layer. This is the hard firewall under the route policy and the main speed win.
/// Patterns are url-filter regexes (WebKit's content-blocker dialect). Keep them anchored to Instagram
/// request paths so the DM surface (/direct/, /api/graphql message ops) is never caught.
public enum ContentRules {
    public static let identifier = "ig-firewall-v1"

    /// Request path fragments to block. Feed, Explore, Reels discovery, suggested/chaining, and ads.
    public static let blockedURLPatterns: [String] = [
        "/api/v1/feed/timeline",
        "/api/v1/feed/reels_tray",
        "/api/v1/discover/web/explore_grid",
        "/api/v1/clips/discover",
        "/api/v1/clips/home",
        "/discover/chaining",
        "/api/v1/discover/topical_explore",
        "/graphql.*PolarisFeedTimelineRootV2Query",
        "/graphql.*PolarisFeedRootPaginationCachedQuery",
        "/graphql.*PolarisStoriesV3AdsPoolQuery",
        "/graphql.*explore",
    ]

    /// Third-party tracking/telemetry hosts & paths (speed + privacy).
    public static let blockedResourcePrefixes: [String] = [
        "/ajax/bz",
        "/logging_client_events",
        "/api/v1/web/launcher/sync",
    ]

    public static func json() -> String {
        let all = blockedURLPatterns + blockedResourcePrefixes
        let rules = all.map { pattern -> [String: Any] in
            ["trigger": ["url-filter": escaped(pattern)], "action": ["type": "block"]]
        }
        let data = try! JSONSerialization.data(withJSONObject: rules, options: [.sortedKeys])
        var json = String(decoding: data, as: UTF8.self)
        // JSONSerialization escapes forward slashes as \/, but we need them unescaped for regex patterns
        json = json.replacingOccurrences(of: "\\/", with: "/")
        return json
    }

    /// url-filter is a regex; escape the one metachar we use literally ("/") stays fine, but "." in a
    /// literal path should match a literal dot. Our patterns already use ".*" intentionally, so only
    /// escape a bare "." that is not part of ".*".
    private static func escaped(_ p: String) -> String {
        // Our patterns are authored as regex already; return as-is. Kept as a seam for future literals.
        p
    }
}
