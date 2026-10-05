import XCTest
@testable import Core

private struct FakeSource: InboxSource {
    let result: Result<InboxSnapshot, Error>
    func fetchInbox() async throws -> InboxSnapshot { try result.get() }
}

private struct Boom: Error {}

final class InboxLoaderTests: XCTestCase {
    private var cache: DiskCache!

    override func setUpWithError() throws {
        cache = try DiskCache(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true))
    }

    override func tearDownWithError() throws {
        try? cache.removeAll()
    }

    func testCachedIsNilBeforeFirstRefresh() {
        let loader = InboxLoader(cache: cache, source: FakeSource(result: .failure(Boom())))
        XCTAssertNil(loader.cached())
    }

    func testRefreshSortsAndSaves() async throws {
        let fetched = InboxSnapshot(threads: [makeThread("old", minutesAgo: 60), makeThread("new", minutesAgo: 1)],
                                    fetchedAt: Date(timeIntervalSinceReferenceDate: 1))
        let loader = InboxLoader(cache: cache, source: FakeSource(result: .success(fetched)))
        let result = try await loader.refresh()
        XCTAssertEqual(result.threads.map(\.id), ["new", "old"])
        XCTAssertEqual(loader.cached(), result)
    }

    func testFailedRefreshKeepsPreviousCache() async throws {
        let good = InboxSnapshot(threads: [makeThread("a")], fetchedAt: Date(timeIntervalSinceReferenceDate: 1))
        _ = try await InboxLoader(cache: cache, source: FakeSource(result: .success(good))).refresh()
        let failing = InboxLoader(cache: cache, source: FakeSource(result: .failure(Boom())))
        do { _ = try await failing.refresh(); XCTFail("expected error") } catch {}
        XCTAssertEqual(failing.cached(), good)
    }

    func testCacheKeysAreIndependent() async throws {
        let snap = InboxSnapshot(threads: [makeThread("sample")], fetchedAt: Date(timeIntervalSinceReferenceDate: 1))
        _ = try await InboxLoader(cache: cache, source: FakeSource(result: .success(snap)), cacheKey: "inbox-sample").refresh()
        XCTAssertNil(InboxLoader(cache: cache, source: FakeSource(result: .failure(Boom()))).cached())
    }
}
