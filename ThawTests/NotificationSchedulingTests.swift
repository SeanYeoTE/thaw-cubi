import XCTest
import UserNotifications
@testable import Thaw

/// Fake notification centre: records what `Reminders` schedules, keyed by identifier like the real one.
final class RecordingScheduler: NotificationScheduling, @unchecked Sendable {
    struct Request: Equatable {
        let date: Date
        let title: String
        let body: String
    }

    private let lock = NSLock()
    private var _pending: [String: Request] = [:]
    private var _authorizationRequests = 0
    var authorized = true

    var pending: [String: Request] { lock.withLock { _pending } }
    var authorizationRequests: Int { lock.withLock { _authorizationRequests } }

    /// One scheduler per call, like the app, each quoting the fun money it was built with.
    func make(funMoney: Decimal) -> any NotificationScheduling { Quoting(base: self, funMoney: funMoney) }

    func requestAuthorizationIfNeeded() async -> Bool {
        lock.withLock { _authorizationRequests += 1 }
        return authorized
    }
    func schedulePaydayReview(at: Date, thawingCount: Int, total: Decimal) async {}
    func scheduleTimerThaw(wantID: UUID, name: String, at: Date) async {}
    func scheduleReminder(at: Date, thawingCount: Int, total: Decimal) async {}
    func pendingIdentifiers() async -> [String] { lock.withLock { Array(_pending.keys) } }
    func cancel(identifiers: [String]) async { lock.withLock { identifiers.forEach { _pending[$0] = nil } } }

    fileprivate func add(_ identifier: String, _ request: Request) {
        lock.withLock { _pending[identifier] = request }
    }

    private struct Quoting: NotificationScheduling {
        let base: RecordingScheduler
        let funMoney: Decimal

        func requestAuthorizationIfNeeded() async -> Bool { await base.requestAuthorizationIfNeeded() }
        func schedulePaydayReview(at date: Date, thawingCount: Int, total: Decimal) async {
            base.add(ThawNotification.paydayIdentifier, payday(date, thawingCount, total))
        }
        func scheduleReminder(at date: Date, thawingCount: Int, total: Decimal) async {
            base.add(ThawNotification.reminderIdentifier, payday(date, thawingCount, total))
        }
        func scheduleTimerThaw(wantID: UUID, name: String, at date: Date) async {
            base.add(ThawNotification.timerPrefix + wantID.uuidString, Request(date: date, title: name, body: ""))
        }
        func pendingIdentifiers() async -> [String] { await base.pendingIdentifiers() }
        func cancel(identifiers: [String]) async { await base.cancel(identifiers: identifiers) }

        private func payday(_ date: Date, _ count: Int, _ total: Decimal) -> Request {
            Request(date: date, title: ThawNotification.paydayTitle(count: count),
                    body: ThawNotification.paydayBody(total: total, funMoney: funMoney))
        }
    }
}

@MainActor
final class NotificationSchedulingTests: XCTestCase {
    private let now = Date.now

    private func want(_ name: String, _ price: Decimal, thawsIn days: Double, status: Want.Status = .cooling) -> Want {
        Want(id: UUID(), name: name, price: price, reason: "", frozenOn: now.addingTimeInterval(-86_400 * 3),
             progress: 0.5, status: status, thawsAt: now.addingTimeInterval(86_400 * days))
    }

    private func makeStore(_ wants: [Want]) -> WantStore {
        let store = WantStore(wants: wants, payday: PaydaySchedule(nextPayday: now.addingTimeInterval(86_400 * 10),
                                                                    funMoney: 300))
        store.save(settings: .default)
        return store
    }

    private func makeReminders(_ store: WantStore, _ scheduler: RecordingScheduler) -> Reminders {
        Reminders(store: store) { scheduler.make(funMoney: $0) }
    }

    /// Payday tab button, then the notification's own action, then a refresh: all three titles must agree.
    private func titlesFromAllPaths(store: WantStore) async -> [String] {
        let scheduler = RecordingScheduler()
        let reminders = makeReminders(store, scheduler)
        var titles: [String] = []

        await withCheckedContinuation { done in reminders.remindTonight { done.resume() } }
        titles.append(scheduler.pending[ThawNotification.reminderIdentifier]?.title ?? "missing")

        await scheduler.cancel(identifiers: [ThawNotification.reminderIdentifier])
        let handler = NotificationActionHandler(reminders: reminders, onRoute: { _ in })
        await handler.handle(actionIdentifier: ThawNotification.remindTonightAction, requestIdentifier: "x", userInfo: [:])
        titles.append(scheduler.pending[ThawNotification.reminderIdentifier]?.title ?? "missing")

        await reminders.refresh(requestingPermission: false).value
        titles.append(scheduler.pending[ThawNotification.paydayIdentifier]?.title ?? "missing")
        return titles
    }

    // MARK: Step 1: "Remind me tonight" survives refresh

    func testTonightReminderSurvivesRefreshAndIsRemovedWhenQueueEmpties() async {
        let lamp = want("Lamp", 120, thawsIn: 5)
        let socks = want("Socks", 12, thawsIn: 1)
        let store = makeStore([lamp, socks])
        let scheduler = RecordingScheduler()
        let reminders = makeReminders(store, scheduler)

        await withCheckedContinuation { done in reminders.remindTonight { done.resume() } }
        XCTAssertNotNil(scheduler.pending[ThawNotification.reminderIdentifier])

        store.add(name: "Book", price: 45, reason: "")
        await reminders.refresh(requestingPermission: false).value
        XCTAssertNotNil(scheduler.pending[ThawNotification.reminderIdentifier], "a refresh after Add must keep the reminder")
        XCTAssertNotNil(scheduler.pending[ThawNotification.paydayIdentifier])
        XCTAssertNotNil(scheduler.pending[ThawNotification.timerPrefix + socks.id.uuidString])

        for id in store.cooling.filter({ $0.price >= 30 }).map(\.id) { store.update(id, status: .skipped) }
        await reminders.refresh(requestingPermission: false).value
        XCTAssertNil(scheduler.pending[ThawNotification.reminderIdentifier], "nothing to review: reminder is removed")
        XCTAssertNil(scheduler.pending[ThawNotification.paydayIdentifier])
        XCTAssertNotNil(scheduler.pending[ThawNotification.timerPrefix + socks.id.uuidString])
    }

    func testRefreshRemovesTimerThawsForWantsNoLongerCooling() async {
        let socks = want("Socks", 12, thawsIn: 1)
        let store = makeStore([socks])
        let scheduler = RecordingScheduler()
        let reminders = makeReminders(store, scheduler)

        await reminders.refresh(requestingPermission: false).value
        XCTAssertEqual(Set(scheduler.pending.keys), [ThawNotification.timerPrefix + socks.id.uuidString])

        store.delete(socks.id)
        await reminders.refresh(requestingPermission: false).value
        XCTAssertTrue(scheduler.pending.isEmpty)
    }

    func testOnlyPaydayAndTimerIdentifiersAreOwnedByRefresh() {
        XCTAssertTrue(Reminders.isOwnedByRefresh(ThawNotification.paydayIdentifier))
        XCTAssertTrue(Reminders.isOwnedByRefresh(ThawNotification.timerPrefix + UUID().uuidString))
        XCTAssertFalse(Reminders.isOwnedByRefresh(ThawNotification.reminderIdentifier))
    }

    // MARK: Step 2: one count for the same payday

    func testAllThreePathsGiveTheSameCountAndTotal() async {
        let thawedTimer = want("Socks", 12, thawsIn: -1)
        let lamp = want("Lamp", 120, thawsIn: 5)
        let desk = want("Desk", 200.5, thawsIn: 9)
        let afterPayday = want("Later", 80, thawsIn: 40)
        let decided = want("Old", 90, thawsIn: -5, status: .bought)
        let store = makeStore([thawedTimer, lamp, desk, afterPayday, decided])
        let reminders = makeReminders(store, RecordingScheduler())

        XCTAssertEqual(reminders.paydaySummary(), PaydaySummary(count: 2, total: Decimal(string: "320.5")!))
        let expected = ThawNotification.paydayTitle(count: 2)
        let titles = await titlesFromAllPaths(store: store)
        XCTAssertEqual(titles, [expected, expected, expected])
    }

    // MARK: Step 3: fun money read when the action runs

    func testActionQuotesFunMoneyChangedAfterTheHandlerWasCreated() async {
        let store = makeStore([want("Lamp", 120, thawsIn: 5)])
        let scheduler = RecordingScheduler()
        let reminders = makeReminders(store, scheduler)
        let handler = NotificationActionHandler(reminders: reminders, onRoute: { _ in })

        var settings = store.effectiveSettings
        settings.funMoney = 875
        store.save(settings: settings)

        await handler.handle(actionIdentifier: ThawNotification.remindTonightAction, requestIdentifier: "x", userInfo: [:])
        let body = scheduler.pending[ThawNotification.reminderIdentifier]?.body
        XCTAssertEqual(body, ThawNotification.paydayBody(total: 120, funMoney: 875))
    }

    // MARK: Permission

    func testRefreshNeverAsksForPermission() async {
        let store = makeStore([want("Lamp", 120, thawsIn: 5), want("Socks", 12, thawsIn: 1)])
        let scheduler = RecordingScheduler()
        let reminders = makeReminders(store, scheduler)

        await reminders.refresh(requestingPermission: false).value
        XCTAssertEqual(scheduler.authorizationRequests, 0)
        XCTAssertFalse(scheduler.pending.isEmpty)
    }

    func testRefreshRequestingPermissionStopsWhenDenied() async {
        let store = makeStore([want("Lamp", 120, thawsIn: 5)])
        let scheduler = RecordingScheduler()
        scheduler.authorized = false
        let reminders = makeReminders(store, scheduler)

        await reminders.refresh(requestingPermission: true).value
        XCTAssertEqual(scheduler.authorizationRequests, 1)
        XCTAssertTrue(scheduler.pending.isEmpty)
    }
}
