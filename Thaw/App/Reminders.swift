import Foundation

/// The count and total one payday notification, the Payday tab's "Remind me tonight" and the notification's own
/// "Remind me tonight" action all quote.
nonisolated struct PaydaySummary: Equatable, Sendable {
    let count: Int
    let total: Decimal
}

/// Keeps scheduled notifications in step with the store. Permission is only requested when asked (D4).
final class Reminders {
    private let store: WantStore
    private let makeScheduler: (Decimal) -> any NotificationScheduling

    // Explicit deinit: the synthesized one on this MainActor class corrupts the heap in the test host.
    deinit {}

    /// The scheduler is rebuilt per call because its copy quotes the current fun money.
    init(store: WantStore,
         makeScheduler: @escaping (Decimal) -> any NotificationScheduling = { UserNotificationScheduler(funMoney: $0) }) {
        self.store = store
        self.makeScheduler = makeScheduler
    }

    /// Payday wants due by the next payday (D2: quick thaws are left out of the payday total).
    // TODO(V5 wave 2): switch to V1's `FunMoneyPlan` so this matches the Payday tab badge and the review.
    func paydaySummary() -> PaydaySummary {
        let threshold = store.effectiveSettings.timerThreshold
        let wants = store.reviewQueue.filter { $0.price >= threshold }
        return PaydaySummary(count: wants.count, total: wants.reduce(Decimal(0)) { $0 + $1.price })
    }

    /// Reschedules the payday review and timer thaws. Only removes the requests it owns, so a pending
    /// "Remind me tonight" survives; that reminder is removed once there is nothing left to review.
    @discardableResult
    func refresh(requestingPermission: Bool) -> Task<Void, Never> {
        let store = store
        let scheduler = makeScheduler(store.effectiveSettings.funMoney)
        let summary = paydaySummary()
        let nextPayday = store.payday.nextPayday
        let threshold = store.effectiveSettings.timerThreshold
        let now = Date.now
        let timers = store.cooling.filter { $0.price < threshold && $0.thawsAt > now }
        return Task {
            if requestingPermission {
                guard await scheduler.requestAuthorizationIfNeeded() else { return }
            }
            var stale = await scheduler.pendingIdentifiers().filter(Self.isOwnedByRefresh)
            if summary.count == 0 { stale.append(ThawNotification.reminderIdentifier) }
            await scheduler.cancel(identifiers: stale)
            if summary.count > 0 {
                await scheduler.schedulePaydayReview(at: nextPayday, thawingCount: summary.count, total: summary.total)
            }
            for want in timers {
                await scheduler.scheduleTimerThaw(wantID: want.id, name: want.name, at: want.thawsAt)
            }
            await scheduler.logPending(context: "refresh")
        }
    }

    nonisolated static func isOwnedByRefresh(_ identifier: String) -> Bool {
        identifier == ThawNotification.paydayIdentifier || identifier.hasPrefix(ThawNotification.timerPrefix)
    }

    /// "Remind me tonight" from the Payday tab: schedules the payday notification again for this evening (sprint-3 D2).
    func remindTonight(completion: @escaping () -> Void) {
        Task {
            await scheduleTonightReminder(requestingPermission: true)
            completion()
        }
    }

    /// Shared by the Payday tab button and the notification's own "Remind me tonight" action.
    func scheduleTonightReminder(requestingPermission: Bool) async {
        let scheduler = makeScheduler(store.effectiveSettings.funMoney)
        let summary = paydaySummary()
        let date = NotificationReminder.tonightDate(now: .now, calendar: .current)
        if requestingPermission {
            guard await scheduler.requestAuthorizationIfNeeded() else { return }
        }
        await scheduler.scheduleReminder(at: date, thawingCount: summary.count, total: summary.total)
        await scheduler.logPending(context: "remind tonight")
    }
}
