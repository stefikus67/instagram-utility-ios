import XCTest
@testable import Core

final class DiskCacheTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testRoundTrip() throws {
        let cache = try DiskCache(directory: dir)
        let snap = InboxSnapshot(threads: [makeThread("a", unread: true)], fetchedAt: Date())
        try cache.save(snap, forKey: "inbox")
        XCTAssertEqual(cache.load(InboxSnapshot.self, forKey: "inbox"), snap)
    }

    func testMissingKeyReturnsNil() throws {
        XCTAssertNil(try DiskCache(directory: dir).load(InboxSnapshot.self, forKey: "nope"))
    }

    func testCorruptFileReturnsNil() throws {
        let cache = try DiskCache(directory: dir)
        try Data("not json".utf8).write(to: dir.appendingPathComponent("inbox.json"))
        XCTAssertNil(cache.load(InboxSnapshot.self, forKey: "inbox"))
    }

    func testRemoveAll() throws {
        let cache = try DiskCache(directory: dir)
        try cache.save(InboxSnapshot(threads: [], fetchedAt: Date()), forKey: "inbox")
        try cache.removeAll()
        XCTAssertNil(cache.load(InboxSnapshot.self, forKey: "inbox"))
    }
}
