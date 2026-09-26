import Foundation

/// Non-sensitive runtime facts shown in Settings. Never put cookies, ids or full URLs here.
@MainActor
final class DiagnosticsStore: ObservableObject {
    @Published var currentHost = "-"
    @Published var currentCategory: RouteCategory?
    @Published var blockedCount = 0
    @Published var lastBlockedSurface: BlockedSurface?

    func recordAllowed(_ url: URL, category: RouteCategory) {
        currentHost = url.host ?? "-"
        currentCategory = category
    }

    func recordBlocked(_ url: URL) {
        blockedCount += 1
        lastBlockedSurface = InstagramRoutePolicy.blockedSurface(for: url)
    }
}
