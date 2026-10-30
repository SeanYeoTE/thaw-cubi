import XCTest
@testable import Thaw

final class BackendStateTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Singapore") ?? .current
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min)) ?? .distantPast
    }

    private func settings(_ rule: PaydayRule) -> PaydaySettings {
        var s = PaydaySettings.default
        s.rule = rule
        return s
    }

    private func next(_ rule: PaydayRule, after: Date) -> Date {
        settings(rule).nextPayday(after: after, calendar: calendar)
    }

    func testSameDateBeforeAndAfter() {
        XCTAssertEqual(next(.sameDate(day: 25), after: date(2026, 11, 10)), date(2026, 11, 25, 9))
        XCTAssertEqual(next(.sameDate(day: 25), after: date(2026, 11, 25, 10)), date(2026, 12, 25, 9))
        XCTAssertEqual(next(.sameDate(day: 25), after: date(2026, 11, 25, 8)), date(2026, 11, 25, 9))
    }

    func testSameDateClampsToMonthEnd() {
        XCTAssertEqual(next(.sameDate(day: 31), after: date(2026, 2, 5)), date(2026, 2, 28, 9))
        XCTAssertEqual(next(.sameDate(day: 31), after: date(2028, 2, 5)), date(2028, 2, 29, 9))
        XCTAssertEqual(next(.sameDate(day: 31), after: date(2026, 4, 30, 10)), date(2026, 5, 31, 9))
    }

    func testSameDateAcrossYear() {
        XCTAssertEqual(next(.sameDate(day: 25), after: date(2026, 12, 26)), date(2027, 1, 25, 9))
    }

    func testLastWorkingDaySkipsWeekend() {
        // 30 Jan 2026 is a Friday; 31 Jan is Saturday.
        XCTAssertEqual(next(.lastWorkingDay, after: date(2026, 1, 10)), date(2026, 1, 30, 9))
        // 30 Apr 2026 is a Thursday.
        XCTAssertEqual(next(.lastWorkingDay, after: date(2026, 4, 1)), date(2026, 4, 30, 9))
        // 31 May 2026 is Sunday, so Friday 29 May.
        XCTAssertEqual(next(.lastWorkingDay, after: date(2026, 5, 1)), date(2026, 5, 29, 9))
        XCTAssertEqual(next(.lastWorkingDay, after: date(2026, 5, 29, 10)), date(2026, 6, 30, 9))
    }

    func testTwiceMonthly() {
        let rule = PaydayRule.twiceMonthly(first: 15, second: 31)
        XCTAssertEqual(next(rule, after: date(2026, 2, 1)), date(2026, 2, 15, 9))
        XCTAssertEqual(next(rule, after: date(2026, 2, 16)), date(2026, 2, 28, 9))
        XCTAssertEqual(next(rule, after: date(2026, 2, 28, 10)), date(2026, 3, 15, 9))
        XCTAssertEqual(next(.twiceMonthly(first: 28, second: 10), after: date(2026, 3, 11)), date(2026, 3, 28, 9))
    }

    func testFixedWait() {
        XCTAssertEqual(next(.fixedWait(days: 7), after: date(2026, 11, 10, 15)), date(2026, 11, 17, 9))
        XCTAssertEqual(next(.fixedWait(days: 7), after: date(2026, 12, 28)), date(2027, 1, 4, 9))
    }

    func testReviewTimeApplied() {
        var s = settings(.sameDate(day: 25))
        s.reviewHour = 18
        s.reviewMinute = 30
        XCTAssertEqual(s.nextPayday(after: date(2026, 11, 1), calendar: calendar), date(2026, 11, 25, 18, 30))
    }

    func testWaitAdvancesOnePayday() {
        let s = settings(.sameDate(day: 25))
        let first = s.nextPayday(after: date(2026, 11, 1), calendar: calendar)
        XCTAssertEqual(s.paydayAfter(first, calendar: calendar), date(2026, 12, 25, 9))
        let f = settings(.fixedWait(days: 7))
        XCTAssertEqual(f.paydayAfter(date(2026, 11, 17, 9), calendar: calendar), date(2026, 11, 24, 9))
    }

    func testFunMoneyUnderAndOver() {
        let under = FunMoneySummary.make(keptPrices: [189], budget: 300)
        XCTAssertEqual(under.remaining, 111)
        XCTAssertEqual(under.overBy, 0)
        XCTAssertEqual(under.fraction, 0.63, accuracy: 0.0001)
        let over = FunMoneySummary.make(keptPrices: [189, 420], budget: 300)
        XCTAssertEqual(over.remaining, -309)
        XCTAssertEqual(over.overBy, 309)
        XCTAssertEqual(over.fraction, 1)
        XCTAssertEqual(FunMoneySummary.make(keptPrices: [], budget: 0).fraction, 0)
    }

    func testPersistenceRoundTrip() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathComponent("state.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = WantStore(fileURL: url)
        XCTAssertNil(store.settings)
        var s = PaydaySettings.default
        s.rule = .twiceMonthly(first: 15, second: 30)
        s.funMoney = Decimal(string: "250.50") ?? 0
        store.save(settings: s)
        store.add(name: "Lamp", price: Decimal(string: "45.25") ?? 0, reason: "Dark desk")
        let reloaded = WantStore(fileURL: url)
        XCTAssertEqual(reloaded.settings, s)
        XCTAssertEqual(reloaded.wants, store.wants)
        XCTAssertEqual(reloaded.wants.first?.price, Decimal(string: "45.25"))
    }

    func testDecideKeepAndWait() {
        let store = WantStore(fileURL: nil)
        store.save(settings: .default)
        store.add(name: "Desk", price: 200, reason: "")
        store.add(name: "Mug", price: 10, reason: "")
        guard let desk = store.wants.first(where: { $0.name == "Desk" }),
              let mug = store.wants.first(where: { $0.name == "Mug" }) else { return XCTFail("missing wants") }
        let before = desk.thawsAt
        store.decide(id: desk.id, keep: false)
        XCTAssertEqual(store.want(id: desk.id)?.status, .cooling)
        XCTAssertGreaterThan(store.want(id: desk.id)?.thawsAt ?? .distantPast, before)
        store.decide(id: mug.id, keep: true)
        XCTAssertEqual(store.want(id: mug.id)?.status, .bought)
    }

    func testThawedWantsOnlyThoseDue() {
        let past = Date.now.addingTimeInterval(-60)
        let future = Date.now.addingTimeInterval(3600)
        let due = Want(id: UUID(), name: "A", price: 50, reason: "", frozenOn: past, progress: 1, status: .cooling, thawsAt: past)
        let waiting = Want(id: UUID(), name: "B", price: 50, reason: "", frozenOn: past, progress: 0, status: .cooling, thawsAt: future)
        let done = Want(id: UUID(), name: "C", price: 50, reason: "", frozenOn: past, progress: 1, status: .bought, thawsAt: past)
        let store = WantStore(wants: [due, waiting, done], payday: WantStore.fixturePayday())
        XCTAssertEqual(store.thawedWants.map(\.name), ["A"])
    }

    func testThawResetAndFixtureLaunch() throws {
        let store = WantStore.launch(arguments: ["-thawFixture", "sprint1"])
        XCTAssertEqual(store.wants.count, 4)
        XCTAssertNil(store.settings)
        let reset = WantStore.launch(arguments: ["-thawReset"])
        XCTAssertTrue(reset.wants.isEmpty)
        XCTAssertNil(reset.settings)
        let fresh = WantStore.launch(arguments: [])
        XCTAssertTrue(fresh.wants.isEmpty)
    }
}
