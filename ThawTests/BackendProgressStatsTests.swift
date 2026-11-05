import XCTest
@testable import Thaw

final class BackendProgressStatsTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ y: Int, _ m: Int, _ d: Int = 25) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 9))!
    }

    private func want(_ price: Decimal, _ status: Want.Status, thaws: Date) -> Want {
        Want(id: UUID(), name: "w", price: price, reason: "r", frozenOn: thaws, progress: 1, status: status, thawsAt: thaws)
    }

    private func stats(_ wants: [Want], now: Date) -> ProgressStats {
        ProgressStats.make(wants: wants, funMoney: 300, now: now, calendar: calendar)
    }

    func testStreakCountsConsecutiveMonths() {
        let wants = [want(50, .skipped, thaws: date(2026, 9)), want(50, .skipped, thaws: date(2026, 10)), want(50, .skipped, thaws: date(2026, 11))]
        XCTAssertEqual(stats(wants, now: date(2026, 11, 28)).streak, 3)
    }

    func testStreakSurvivesCurrentMonthWithNoSkipYet() {
        let wants = [want(50, .skipped, thaws: date(2026, 9)), want(50, .skipped, thaws: date(2026, 10))]
        XCTAssertEqual(stats(wants, now: date(2026, 11, 3)).streak, 2)
    }

    func testStreakBreaksOnGapAndWhenLastSkipIsOld() {
        let gap = [want(50, .skipped, thaws: date(2026, 8)), want(50, .skipped, thaws: date(2026, 10))]
        XCTAssertEqual(stats(gap, now: date(2026, 10, 28)).streak, 1)
        XCTAssertEqual(stats(gap, now: date(2026, 12, 28)).streak, 0)
    }

    func testBoughtAndCoolingDoNotExtendStreak() {
        let wants = [want(50, .bought, thaws: date(2026, 10)), want(50, .cooling, thaws: date(2026, 10))]
        XCTAssertEqual(stats(wants, now: date(2026, 10, 28)).streak, 0)
    }

    func testFunMoneyMonthsAndWinRate() {
        let wants = [want(450, .skipped, thaws: date(2026, 10)), want(100, .bought, thaws: date(2026, 10)),
                     want(100, .bought, thaws: date(2026, 10)), want(20, .cooling, thaws: date(2026, 11))]
        let result = stats(wants, now: date(2026, 11, 3))
        XCTAssertEqual(result.funMoneyMonths, 1.5, accuracy: 0.001)
        XCTAssertEqual(result.winRatePercent, 33)
        XCTAssertEqual(result.decidedCount, 3)
    }

    func testNoDecidedWantsIsAllZero() {
        let result = stats([want(20, .cooling, thaws: date(2026, 11))], now: date(2026, 11, 3))
        XCTAssertEqual(result.winRatePercent, 0)
        XCTAssertEqual(result.streak, 0)
    }
}
