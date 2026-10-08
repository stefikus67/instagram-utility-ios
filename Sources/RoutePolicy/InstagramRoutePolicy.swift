import Foundation

/// How the app treats a navigation target. Pure logic: no UIKit/WebKit, so it is unit-testable anywhere.
enum RouteCategory: String, Equatable, CaseIterable {
    case authAllowed = "AUTH_ALLOWED"
    case directAllowed = "DIRECT_ALLOWED"
    case profileAllowed = "PROFILE_ALLOWED"
    case storiesAllowed = "STORIES_ALLOWED"
    case createAllowed = "CREATE_ALLOWED"
    case mediaAllowed = "MEDIA_ALLOWED"
    case searchAllowed = "SEARCH_ALLOWED"
    /// Your own account pages: edit profile, settings, archive, your activity.
    case settingsAllowed = "SETTINGS_ALLOWED"
    case blocked = "BLOCKED"
    case external = "EXTERNAL"

    /// True when the URL may be shown inside the in-app web view.
    var isAllowedInApp: Bool {
        switch self {
        case .authAllowed, .directAllowed, .profileAllowed, .storiesAllowed, .createAllowed, .mediaAllowed, .searchAllowed, .settingsAllowed: return true
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

    static let createStoryURL = URL(string: "https://www.instagram.com/create/story/")!
    static let searchURL = URL(string: "https://www.instagram.com/explore/search/")!
    /// Instagram's home page (the feed). `classify` keeps it `.blocked`; only the story composer overrides that.
    static let homeURL = URL(string: "https://www.instagram.com/")!

    /// True for Instagram's home page: an Instagram host and no path segments (query ignored).
    static func isHome(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
              let host = url.host?.lowercased(), instagramHosts.contains(host) else { return false }
        return segments(of: url).isEmpty
    }

    /// The profile page for an exact username, or nil when the text is not a plausible username or the
    /// resulting route would not be a profile the policy allows (e.g. "explore", "direct").
    static func profileURL(username: String) -> URL? {
        var name = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if name.hasPrefix("@") { name.removeFirst() }
        guard (1...30).contains(name.count),
              name.unicodeScalars.allSatisfy({ ("a"..."z").contains($0) || ("0"..."9").contains($0) || $0 == "." || $0 == "_" })
        else { return nil }
        guard let url = URL(string: "https://www.instagram.com/\(name)/"),
              classify(url) == .profileAllowed else { return nil }
        return url
    }

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
        if isSettingsPath(segs) { return .settingsAllowed }
        if first == "create" { return .createAllowed }
        if first == "stories" { return .storiesAllowed }
        if first == "explore" {
            if segs.count > 1 && segs[1] == "search" {
                return .searchAllowed
            }
            return .blocked
        }
        if isMediaPath(segs) {
            guard let source = source else { return .blocked }
            let src = classify(source)
            let validSource: Set<RouteCategory> = [.directAllowed, .profileAllowed, .storiesAllowed, .settingsAllowed]
            if validSource.contains(src) { return .mediaAllowed }
            if isMediaPath(segments(of: source)), sameRoute(source, url) { return .mediaAllowed }
            return .blocked
        }
        if isProfilePath(segs) { return .profileAllowed }
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

    private static let reservedFirstSegments: Set<String> = [
        "explore", "reels", "direct", "accounts", "stories", "p", "reel", "tv",
        "create", "challenge", "auth_platform", "consent", "privacy",
        "notifications", "emails", "settings", "api", "graphql", "ajax", "archive", "your_activity",
    ]
    private static let profileSubpages: Set<String> = ["reels", "tagged", "saved", "feed"]

    /// A user profile: "/<username>/" or "/<username>/<reels|tagged|...>/". Never a reserved word.
    private static func isProfilePath(_ segs: [String]) -> Bool {
        guard let first = segs.first, !reservedFirstSegments.contains(first) else { return false }
        if segs.count == 1 { return true }
        if segs.count == 2 { return profileSubpages.contains(segs[1]) }
        return false
    }

    /// Own-account pages, reached from your profile: /accounts/<page>/ (edit, settings, privacy...), /archive/...,
    /// /your_activity/... Bare /accounts/, sign-up and logout stay blocked (sign out is Settings → Reset).
    private static let settingsTopLevel: Set<String> = ["archive", "your_activity"]
    private static let accountsBlocked: Set<String> = ["emailsignup", "logout"]
    private static func isSettingsPath(_ segs: [String]) -> Bool {
        guard let first = segs.first else { return false }
        if first == "accounts" { return segs.count > 1 && !accountsBlocked.contains(segs[1]) }
        return settingsTopLevel.contains(first)
    }

    private static func isAuthPath(_ segs: [String]) -> Bool {
        guard let first = segs.first else { return false }
        if first == "accounts" { return segs.count > 1 && accountsAllowed.contains(segs[1]) }
        return authTopLevel.contains(first)
    }

    /// /p/<code>, /reel/<code>, /tv/<code>, or /<user>/p|reel/<code>. Nothing deeper (no /audio/, /liked_by/).
    private static func isMediaPath(_ segs: [String]) -> Bool {
        if segs.count == 2 { return mediaTopLevel.contains(segs[0]) }
        if segs.count == 3 {
            return !reservedFirstSegments.contains(segs[0]) && mediaUnderUser.contains(segs[1])
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
