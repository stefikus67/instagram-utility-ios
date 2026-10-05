import Foundation

/// The one definition of "this host is Instagram", shared by the session cookie check and the
/// microphone permission gate. Exact match or a true subdomain only, never a lookalike.
enum InstagramHost {
    static func isInstagram(_ host: String) -> Bool {
        var h = host.lowercased()
        if h.hasPrefix(".") { h.removeFirst() }
        return h == "instagram.com" || h.hasSuffix(".instagram.com")
    }
}
