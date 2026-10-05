import XCTest
@testable import Core

func makeThread(_ id: String, title: String? = nil, preview: String = "hi",
                minutesAgo: Double = 0, pinned: Bool = false, unread: Bool = false) -> ThreadSummary {
    let base = Date(timeIntervalSinceReferenceDate: 800_000_000)
    return ThreadSummary(id: id, title: title ?? id, avatarURL: nil, lastMessagePreview: preview,
                         lastActivity: base.addingTimeInterval(-minutesAgo * 60), isUnread: unread, isPinned: pinned)
}

final class InboxRulesTests: XCTestCase {
    func testNewestFirst() {
        let sorted = InboxOrdering.sorted([makeThread("old", minutesAgo: 60), makeThread("new", minutesAgo: 1)])
        XCTAssertEqual(sorted.map(\.id), ["new", "old"])
    }

    func testPinnedBeforeNewer() {
        let sorted = InboxOrdering.sorted([
            makeThread("recent", minutesAgo: 1),
            makeThread("pinnedOld", minutesAgo: 600, pinned: true),
        ])
        XCTAssertEqual(sorted.map(\.id), ["pinnedOld", "recent"])
    }

    func testTiesAreStableById() {
        let sorted = InboxOrdering.sorted([makeThread("b"), makeThread("a")])
        XCTAssertEqual(sorted.map(\.id), ["a", "b"])
    }

    func testEmptyQueryReturnsAll() {
        let threads = [makeThread("a"), makeThread("b")]
        XCTAssertEqual(InboxSearch.filter(threads, query: "   "), threads)
    }

    func testSearchMatchesTitleCaseInsensitively() {
        let threads = [makeThread("1", title: "Luka"), makeThread("2", title: "Maja")]
        XCTAssertEqual(InboxSearch.filter(threads, query: "lu").map(\.id), ["1"])
    }

    func testSearchMatchesPreview() {
        let threads = [makeThread("1", title: "Ana", preview: "see you saturday"), makeThread("2", title: "Tim")]
        XCTAssertEqual(InboxSearch.filter(threads, query: "Saturday").map(\.id), ["1"])
    }

    func testSearchIsDiacriticInsensitive() {
        let threads = [makeThread("1", title: "Žiga"), makeThread("2", title: "Maja")]
        XCTAssertEqual(InboxSearch.filter(threads, query: "ziga").map(\.id), ["1"])
        XCTAssertEqual(InboxSearch.filter(threads, query: "ŽIGA").map(\.id), ["1"])
    }
}
