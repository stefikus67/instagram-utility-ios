import Foundation

/// How the app treats a navigation target. Pure logic: no UIKit/WebKit, so it is unit-testable anywhere.
enum RouteCategory: String, Equatable, CaseIterable {
    case authAllowed = "AUTH_ALLOWED"
    case directAllowed = "DIRECT_ALLOWED"
    case dmMediaAllowedOnce = "DM_MEDIA_ALLOWED_ONCE"
    case blocked = "BLOCKED"
    case external = "EXTERNAL"

    /// True when the URL may be shown inside the in-app web view.
    var isAllowedInApp: Bool {
        switch self {
        case .authAllowed, .directAllowed, .dmMediaAllowedOnce: return true
        case .blocked, .external: return false
        }
    }
}

/// Coarse label for a blocked route, used only for diagnostics (never contains usernames or ids).
enum BlockedSurface: String, Equatable {
    case home, explore, reels, stories, mediaOutsideDirect, profileOrOther
}

/// The attention firewall. Default-deny: only routes listed here are reachable.
///
/// `source` is the last route the user was allowed to be on. It is what makes the
/// DM-media exception work: a post/reel is only viewable when reached from /direct/.
enum InstagramRoutePolicy {
    static let inboxURL = URL(string: "https://www.instagram.com/direct/inbox/")!
    static let loginURL = URL(string: "https://www.instagram.com/accounts/login/?next=%2Fdirect%2Finbox%2F")!

    private static let instagramHosts: Set<String> = ["instagram.com", "www.instagram.com", "m.instagram.com"]
    /// Account Center / accounts hosts are only used by auth and security flows.
    private static let authHosts: Set<String> = ["accounts.instagram.com", "accountscenter.instagram.com"]
    private static let authTopLevel: Set<String> = ["challenge", "auth_platform", "consent", "privacy"]
    private static let accountsAllowed: Set<String> = ["login", "onetap", "two_factor", "password", "suspended", "consent"]
    private static let mediaTopLevel: Set<String> = ["p", "reel", "tv"]
    private static let mediaUnderUser: Set<String> = ["p", "reel"]

    static func classify(_ url: URL, from source: URL? = nil) -> RouteCategory {
        let scheme = url.scheme?.lowercased() ?? ""
        if url.absoluteString == "about:blank" { return .authAllowed }
        guard scheme == "https" || scheme == "http" else { return .external }
        guard let host = url.host?.lowercased() else { return .external }
        if authHosts.contains(host) { return .authAllowed }
        guard instagramHosts.contains(host) else { return .external }

        let segs = segments(of: url)
        guard let first = segs.first else { return .blocked } // "/" is the Home feed

        if first == "direct" { return .directAllowed }
        if isAuthPath(segs) { return .authAllowed }
        if isMediaPath(segs) {
            guard let source = source else { return .blocked }
            if classify(source) == .directAllowed { return .dmMediaAllowedOnce }
            // Query/fragment-only change on the media page already opened from a DM (e.g. carousel index).
            if isMediaPath(segments(of: source)), sameRoute(source, url) { return .dmMediaAllowedOnce }
            return .blocked
        }
        return .blocked
    }

    static func blockedSurface(for url: URL) -> BlockedSurface {
        let segs = segments(of: url)
        guard let first = segs.first else { return .home }
        switch first {
        case "explore": return .explore
        case "reels": return .reels
        case "stories": return .stories
        default: return isMediaPath(segs) ? .mediaOutsideDirect : .profileOrOther
        }
    }

    static func sameRoute(_ a: URL, _ b: URL) -> Bool {
        a.host?.lowercased() == b.host?.lowercased() && segments(of: a) == segments(of: b)
    }

    // MARK: - Path helpers

    private static func isAuthPath(_ segs: [String]) -> Bool {
        guard let first = segs.first else { return false }
        if first == "accounts" { return segs.count > 1 && accountsAllowed.contains(segs[1]) }
        return authTopLevel.contains(first)
    }

    /// /p/<code>, /reel/<code>, /tv/<code>, or /<user>/p|reel/<code>. Nothing deeper (no /audio/, /liked_by/).
    private static func isMediaPath(_ segs: [String]) -> Bool {
        if segs.count == 2 { return mediaTopLevel.contains(segs[0]) }
        if segs.count == 3 {
            let reserved: Set<String> = ["explore", "reels", "direct", "accounts", "stories", "p", "reel", "tv"]
            return !reserved.contains(segs[0]) && mediaUnderUser.contains(segs[1])
        }
        return false
    }

    /// Lowercased, percent-decoded path segments with `.`/`..`/empty segments resolved,
    /// so `/direct/../explore` and `//explore` cannot slip past prefix checks.
    private static func segments(of url: URL) -> [String] {
        let rawPath = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? url.path
        var out: [String] = []
        for part in rawPath.split(separator: "/", omittingEmptySubsequences: true) {
            let s = (String(part).removingPercentEncoding ?? String(part)).lowercased()
            if s == "." { continue }
            if s == ".." { _ = out.popLast(); continue }
            out.append(s)
        }
        return out
    }
}
