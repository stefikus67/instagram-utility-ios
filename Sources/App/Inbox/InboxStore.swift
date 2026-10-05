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
            guard showsSampleData != oldValue else { return }
            UserDefaults.standard.set(showsSampleData, forKey: Self.sampleKey)
            Task { await reload() }
        }
    }

    private let cache: DiskCache
    private var reloadTask: Task<Void, Never>?

    init(cache: DiskCache) {
        self.cache = cache
        showsSampleData = UserDefaults.standard.bool(forKey: Self.sampleKey)
        snapshot = loader?.cached()
    }

    private var loader: InboxLoader? {
        showsSampleData ? InboxLoader(cache: cache, source: SampleInboxSource(), cacheKey: "inbox-sample") : nil
    }

    /// Latest call wins: an older in-flight reload is cancelled and its result discarded.
    func reload() async {
        reloadTask?.cancel()
        let task = Task { await performReload() }
        reloadTask = task
        await task.value
    }

    private func performReload() async {
        let sample = showsSampleData
        guard let loader else {
            snapshot = nil
            lastError = nil
            return
        }
        if snapshot == nil { snapshot = loader.cached() }
        do {
            let fresh = try await loader.refresh()
            // The mode may have flipped (or the cache been cleared) while awaiting; drop stale results.
            guard !Task.isCancelled, showsSampleData == sample else { return }
            snapshot = fresh
            lastError = nil
        } catch {
            guard !Task.isCancelled, showsSampleData == sample, !(error is CancellationError) else { return }
            // Never surface response bodies or identifiers.
            lastError = "Couldn't refresh"
        }
    }

    /// Used by Reset Session: removes every cached file.
    func clearAll() {
        reloadTask?.cancel()
        showsSampleData = false // persists the off state and reloads to an empty snapshot
        try? cache.removeAll()
        snapshot = nil
        lastError = nil
    }
}
