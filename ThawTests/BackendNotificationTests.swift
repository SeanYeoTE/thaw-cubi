import XCTest
@testable import Thaw

final class BackendNotificationTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Singapore") ?? .current
        return c
    }

    private func date(_ d: Int, _ h: Int, _ m: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: d, hour: h, minute: m)) ?? .distantPast
    }

    func testBeforeEightPmSchedulesTonight() {
        XCTAssertEqual(NotificationReminder.tonightDate(now: date(25, 9, 30), calendar: calendar), date(25, 20))
        XCTAssertEqual(NotificationReminder.tonightDate(now: date(25, 19, 59), calendar: calendar), date(25, 20))
    }

    func testAtOrAfterEightPmAddsOneHour() {
        XCTAssertEqual(NotificationReminder.tonightDate(now: date(25, 20), calendar: calendar), date(25, 21))
        XCTAssertEqual(NotificationReminder.tonightDate(now: date(25, 22, 15), calendar: calendar), date(25, 23, 15))
        XCTAssertEqual(NotificationReminder.tonightDate(now: date(25, 23, 30), calendar: calendar), date(26, 0, 30))
    }

    func testMidnightSchedulesTonight() {
        XCTAssertEqual(NotificationReminder.tonightDate(now: date(25, 0), calendar: calendar), date(25, 20))
    }
}
