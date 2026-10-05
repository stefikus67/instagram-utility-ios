import Foundation

/// Cache-first inbox: `cached()` is instant for app start, `refresh()` fetches, sorts and saves.
public struct InboxLoader {
    public static let defaultCacheKey = "inbox"

    private let cache: DiskCache
    private let source: InboxSource
    private let cacheKey: String

    public init(cache: DiskCache, source: InboxSource, cacheKey: String = InboxLoader.defaultCacheKey) {
        self.cache = cache
        self.source = source
        self.cacheKey = cacheKey
    }

    public func cached() -> InboxSnapshot? {
        cache.load(InboxSnapshot.self, forKey: cacheKey)
    }

    /// On failure the previous cache is left untouched and the error is rethrown.
    public func refresh() async throws -> InboxSnapshot {
        var snapshot = try await source.fetchInbox()
        snapshot.threads = InboxOrdering.sorted(snapshot.threads)
        try cache.save(snapshot, forKey: cacheKey)
        return snapshot
    }
}
