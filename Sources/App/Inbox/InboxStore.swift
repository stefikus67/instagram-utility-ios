import Foundation

/// Inbox state for the Messages screen. Shows the cache instantly, then refreshes.
/// Until the live InstagramClient exists (next plan), only the sample source is connected.
@MainActor
final class InboxStore: ObservableObject {
    private static let sampleKey = "showsSampleInbox"

    @Published private(set) var snapshot: InboxSnapshot?
    @Published private(set) var lastError: String?
    @Published var showsSampleData: Bool {
        didSet {
            UserDefaults.standard.set(showsSampleData, forKey: Self.sampleKey)
            Task { await reload() }
        }
    }

    private let cache: DiskCache

    init(cache: DiskCache) {
        self.cache = cache
        showsSampleData = UserDefaults.standard.bool(forKey: Self.sampleKey)
        snapshot = loader?.cached()
    }

    private var loader: InboxLoader? {
        showsSampleData ? InboxLoader(cache: cache, source: SampleInboxSource(), cacheKey: "inbox-sample") : nil
    }

    func reload() async {
        guard let loader else {
            snapshot = nil
            return
        }
        if snapshot == nil { snapshot = loader.cached() }
        do {
            snapshot = try await loader.refresh()
            lastError = nil
        } catch {
            // Never surface response bodies or identifiers.
            lastError = "Couldn't refresh"
        }
    }

    /// Used by Reset Session: removes every cached file.
    func clearAll() {
        try? cache.removeAll()
        snapshot = nil
    }
}
