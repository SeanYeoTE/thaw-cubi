import XCTest
@testable import Thaw

final class BackendGoalTests: XCTestCase {
    private let calendar = Calendar.current

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h)) ?? .distantPast
    }

    private func goal(_ name: String, target: Decimal, saved: Decimal = 0, deadline: Date? = nil,
                      created: Date? = nil, status: Goal.Status = .active) -> Goal {
        Goal(name: name, target: target, saved: saved, deadline: deadline,
             createdOn: created ?? date(2026, 8, 1), status: status)
    }

    private func want(_ name: String, _ price: Decimal, _ status: Want.Status, decided: Date?) -> Want {
        Want(id: UUID(), name: name, price: price, reason: "", frozenOn: date(2026, 11, 1), progress: 1,
             status: status, thawsAt: date(2026, 11, 25), decidedOn: decided)
    }

    // MARK: Ledger

    func testFillOrderDeadlineAscNilLastOldestFirst() {
        let late = goal("late", target: 500, deadline: date(2027, 3, 31))
        let soon = goal("soon", target: 500, deadline: date(2026, 12, 25))
        let oldNone = goal("oldNone", target: 500, created: date(2026, 1, 1))
        let newNone = goal("newNone", target: 500, created: date(2026, 9, 1))
        let archived = goal("archived", target: 500, deadline: date(2026, 1, 1), status: .archived)
        let order = GoalLedger.fillOrder([newNone, late, archived, oldNone, soon]).map(\.name)
        XCTAssertEqual(order, ["soon", "late", "oldNone", "newNone"])
    }

    func testPoolAndValidate() {
        XCTAssertEqual(GoalLedger.pool(skipped: 489, unspent: 111), 600)
        XCTAssertEqual(GoalLedger.pool(skipped: 0, unspent: 0), 0)
        XCTAssertTrue(GoalLedger.validate(target: 300.01, funMoney: 300))
        XCTAssertFalse(GoalLedger.validate(target: 300, funMoney: 300))
    }

    func testOverflowAndCompletion() {
        let a = goal("a", target: 400, saved: 300, deadline: date(2026, 12, 1))
        let b = goal("b", target: 1000)
        let result = GoalLedger.consolidate(pool: 250, goals: [b, a], month: date(2026, 11, 1))
        XCTAssertEqual(result.applied[a.id], 100)
        XCTAssertEqual(result.applied[b.id], 150)
        XCTAssertEqual(result.completed, [a.id])
        XCTAssertEqual(result.keptRemainder, 0)
        XCTAssertEqual(result.goals.map(\.name), ["b", "a"])
        let done = result.goals[1]
        XCTAssertEqual(done.status, .completed)
        XCTAssertEqual(done.history.map(\.kind), [.contribution, .completed])
        XCTAssertEqual(result.goals[0].status, .active)
    }

    func testAllFullKeepsRemainder() {
        let a = goal("a", target: 400, saved: 350)
        let result = GoalLedger.consolidate(pool: 600, goals: [a], month: date(2026, 11, 1))
        XCTAssertEqual(result.keptRemainder, 550)
        XCTAssertEqual(result.goals[0].saved, 400)
    }

    func testExtendOverdue() {
        let settings = PaydaySettings.default
        let overdue = goal("o", target: 900, saved: 100, deadline: date(2026, 11, 25, 9))
        let funded = goal("f", target: 900, saved: 900, deadline: date(2026, 11, 25, 9))
        let future = goal("x", target: 900, deadline: date(2027, 3, 31))
        let out = GoalLedger.extendOverdue([overdue, funded, future], now: date(2026, 11, 30), settings: settings)
        XCTAssertEqual(out[0].deadline, date(2026, 12, 25, 9))
        XCTAssertTrue(out[0].isExtended)
        XCTAssertEqual(out[0].history.last?.newDeadline, date(2026, 12, 25, 9))
        XCTAssertEqual(out[1], funded)
        XCTAssertEqual(out[2], future)
    }

    func testProgress() {
        XCTAssertEqual(goal("p", target: 800, saved: 200).progress, 0.25, accuracy: 0.0001)
        XCTAssertEqual(goal("p", target: 800, saved: 900).progress, 1)
    }

    // MARK: Store

    private func sampleStore() -> (WantStore, espresso: Goal, japan: Goal, laptop: Goal) {
        let decided = date(2026, 11, 10)
        let store = WantStore(wants: [
            want("Keyboard", 189, .bought, decided: decided),
            want("Overshirt", 69, .skipped, decided: decided),
            want("Grinder", 420, .skipped, decided: decided),
            want("Old skip", 50, .skipped, decided: date(2026, 10, 5)),
            want("Legacy", 80, .skipped, decided: nil),
        ])
        let espresso = Goal(name: "Espresso setup", target: 900, saved: 410, deadline: date(2026, 12, 25, 9),
                            createdOn: date(2026, 8, 1))
        let japan = Goal(name: "Japan trip", target: 2000, saved: 1262, deadline: date(2027, 3, 31),
                         createdOn: date(2026, 8, 1))
        let laptop = Goal(name: "New laptop", target: 1800, createdOn: date(2026, 8, 1))
        store.goalState.goals = [laptop, japan, espresso]
        store.goalState.lastMonth = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1))
        return (store, espresso, japan, laptop)
    }

    func testPendingPool() {
        let (store, _, _, _) = sampleStore()
        let pool = store.pendingPool(now: date(2026, 11, 20))
        XCTAssertEqual(pool.skipped, 489)
        XCTAssertEqual(pool.unspent, 111)
        XCTAssertEqual(pool.total, 600)
    }

    func testUnspentFlooredAtZero() {
        let store = WantStore(wants: [want("Big", 500, .bought, decided: date(2026, 11, 3))])
        XCTAssertEqual(store.pendingPool(now: date(2026, 11, 20)).unspent, 0)
    }

    func testSampleScenarioMonthEnd() throws {
        let (store, espresso, japan, laptop) = sampleStore()
        XCTAssertNil(store.runMonthEndIfNeeded(now: date(2026, 11, 30)) .map { _ in 1 }, "month not over yet")
        let summary = try XCTUnwrap(store.runMonthEndIfNeeded(now: date(2026, 12, 1)))
        XCTAssertEqual(summary.pool, 600)
        XCTAssertEqual(summary.skipped, 489)
        XCTAssertEqual(summary.unspent, 111)
        XCTAssertEqual(summary.applied.map(\.amount), [490, 110])
        XCTAssertEqual(summary.applied.map(\.completed), [true, false])
        XCTAssertEqual(summary.keptRemainder, 0)
        XCTAssertEqual(store.goal(id: espresso.id)?.saved, 900)
        XCTAssertEqual(store.goal(id: espresso.id)?.status, .completed)
        XCTAssertEqual(store.goal(id: japan.id)?.saved, 1372)
        XCTAssertEqual(store.goal(id: laptop.id)?.saved, 0)
        XCTAssertEqual(store.monthEndSummary, summary)
        XCTAssertEqual(store.finishedGoals.map(\.id), [espresso.id])
        XCTAssertEqual(store.activeGoals.map(\.id), [japan.id, laptop.id])
    }

    func testMonthEndIdempotent() throws {
        let (store, _, japan, _) = sampleStore()
        XCTAssertNotNil(store.runMonthEndIfNeeded(now: date(2026, 12, 1)))
        let before = store.goals
        XCTAssertNil(store.runMonthEndIfNeeded(now: date(2026, 12, 2)))
        XCTAssertNil(store.runMonthEndIfNeeded(now: date(2026, 12, 15)))
        XCTAssertEqual(store.goals, before)
        XCTAssertEqual(store.goal(id: japan.id)?.saved, 1372)
    }

    func testMonthEndNilWithoutGoals() {
        let store = WantStore(wants: [])
        XCTAssertNil(store.runMonthEndIfNeeded(now: date(2026, 12, 1)))
    }

    func testMonthEndExtendsOverdueSilently() {
        let store = WantStore(wants: [])
        store.goalState.goals = [goal("o", target: 900, deadline: date(2026, 11, 25, 9), created: date(2026, 11, 2))]
        store.goalState.lastMonth = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1))
        XCTAssertNil(store.runMonthEndIfNeeded(now: date(2026, 11, 28)))
        XCTAssertEqual(store.goals[0].deadline, date(2026, 12, 25, 9))
        XCTAssertTrue(store.goals[0].isExtended)
        XCTAssertNil(store.monthEndSummary)
    }

    func testGoalCRUDAndValidation() throws {
        let store = WantStore(wants: [])
        XCTAssertThrowsError(try store.addGoal(name: "x", target: 300, deadline: nil, now: .now)) {
            XCTAssertEqual($0 as? GoalError, .targetTooLow)
        }
        XCTAssertThrowsError(try store.addGoal(name: "  ", target: 500, deadline: nil, now: .now)) {
            XCTAssertEqual($0 as? GoalError, .emptyName)
        }
        let g = try store.addGoal(name: "Bike", target: 500, deadline: nil, now: .now)
        try store.updateGoal(id: g.id, name: "E-bike", target: 800, deadline: date(2027, 1, 1))
        XCTAssertEqual(store.goal(id: g.id)?.name, "E-bike")
        XCTAssertThrowsError(try store.updateGoal(id: g.id, name: "E-bike", target: 100, deadline: nil))
        store.archiveGoal(id: g.id)
        XCTAssertEqual(store.finishedGoals.count, 1)
        store.deleteGoal(id: g.id)
        XCTAssertTrue(store.goals.isEmpty)
    }

    func testLoweringTargetBelowSavedCompletesGoal() throws {
        let store = WantStore(wants: [])
        let g = try store.addGoal(name: "Bike", target: 1000, deadline: nil, now: .now)
        store.goalState.goals[0].saved = 400
        try store.updateGoal(id: g.id, name: "Bike", target: 350, deadline: nil)
        XCTAssertEqual(store.goal(id: g.id)?.status, .completed)
        XCTAssertNotNil(store.goal(id: g.id)?.completedOn)
        XCTAssertEqual(store.goal(id: g.id)?.history.last?.kind, .completed)
    }

    func testDecidedOnSet() {
        let want = Want(id: UUID(), name: "a", price: 100, reason: "", frozenOn: .now, progress: 0, status: .cooling)
        let store = WantStore(wants: [want, Want(id: UUID(), name: "b", price: 100, reason: "", frozenOn: .now,
                                                 progress: 0, status: .cooling)])
        let now = date(2026, 11, 5)
        store.decide(id: want.id, keep: true, now: now)
        XCTAssertEqual(store.want(id: want.id)?.decidedOn, now)
        let other = store.wants[1].id
        store.update(other, status: .skipped)
        XCTAssertNotNil(store.want(id: other)?.decidedOn)
    }

    func testInviteHiddenAndDismissAndPersistence() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("thaw-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = WantStore(fileURL: url)
        let g = try store.addGoal(name: "Bike", target: 500, deadline: nil, now: date(2026, 11, 2))
        store.hideGoalInvite(until: date(2026, 12, 4))
        let reloaded = WantStore(fileURL: url)
        XCTAssertEqual(reloaded.goals, [g])
        XCTAssertEqual(reloaded.goalInviteHiddenUntil, date(2026, 12, 4))
        reloaded.goalState.summary = MonthEndSummary(month: .now, pool: 1, skipped: 1, unspent: 0, applied: [], keptRemainder: 1)
        reloaded.dismissMonthEndSummary()
        XCTAssertNil(WantStore(fileURL: url).monthEndSummary)
    }

    func testOldSaveDecodes() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("thaw-old-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let id = UUID().uuidString
        let json = """
        {"wants":[{"id":"\(id)","name":"Old","price":12,"reason":"r","frozenOn":0,"progress":0.5,
        "status":"skipped","thawsAt":100}]}
        """
        try json.write(to: url, atomically: true, encoding: .utf8)
        let store = WantStore(fileURL: url)
        XCTAssertEqual(store.wants.count, 1)
        XCTAssertNil(store.wants[0].decidedOn)
        XCTAssertTrue(store.goals.isEmpty)
        XCTAssertNil(store.monthEndSummary)
        XCTAssertNil(store.goalInviteHiddenUntil)
    }
}
