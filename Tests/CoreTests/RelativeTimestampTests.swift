import XCTest
@testable import Core

final class RelativeTimestampTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    private let locale = Locale(identifier: "en_US_POSIX")

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 12, _ mi: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }

    // 2026-10-05 is a Monday.
    private var now: Date { date(2026, 10, 5, 15, 0) }

    private func s(_ d: Date) -> String {
        RelativeTimestamp.string(for: d, now: now, calendar: calendar, locale: locale)
    }

    func testSameDayShowsTime() { XCTAssertEqual(s(date(2026, 10, 5, 9, 7)), "09:07") }
    func testYesterdayShowsWeekday() { XCTAssertEqual(s(date(2026, 10, 4, 23, 59)), "Sun") }
    func testSixDaysAgoShowsWeekday() { XCTAssertEqual(s(date(2026, 9, 29)), "Tue") }
    func testSevenDaysAgoShowsDate() { XCTAssertEqual(s(date(2026, 9, 28)), "28.9.26") }
    func testFutureShowsDate() { XCTAssertEqual(s(date(2026, 10, 9)), "9.10.26") }
}
