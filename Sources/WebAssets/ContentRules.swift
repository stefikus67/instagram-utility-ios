import Foundation

/// A WKContentRuleList source that blocks Instagram's feed/Explore/Reels/ads/tracking requests at the
/// network layer. This is the hard firewall under the route policy and the main speed win.
/// Patterns are url-filter regexes (WebKit's content-blocker dialect). Keep them anchored to Instagram
/// request paths so the DM surface (/direct/, /api/graphql message ops) is never caught.
public enum ContentRules {
    public static let identifier = "ig-firewall-v1"

    /// Request path fragments to block. Feed, Explore, Reels discovery, suggested/chaining, and ads.
    /// GraphQL feed/ads requests can't be matched here (op name is in the POST body); those are blocked by navigation via InstagramRoutePolicy, not the content list.
    public static let blockedURLPatterns: [String] = [
        "/api/v1/feed/timeline",
        "/api/v1/discover/web/explore_grid",
        "/api/v1/clips/discover",
        "/api/v1/clips/home",
        "/discover/chaining",
        "/api/v1/discover/topical_explore",
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
            ["trigger": ["url-filter": pattern], "action": ["type": "block"]]
        }
        let data = try! JSONSerialization.data(withJSONObject: rules, options: [.sortedKeys, .withoutEscapingSlashes])
        return String(decoding: data, as: UTF8.self)
    }
}
