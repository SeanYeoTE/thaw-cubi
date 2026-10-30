import Foundation

/// Keeps scheduled notifications in step with the store. Permission is only requested when asked (D4).
final class Reminders {
    private let store: WantStore
    private let makeScheduler: (Decimal) -> any NotificationScheduling

    /// The scheduler is rebuilt per refresh because its copy quotes the current fun money.
    init(store: WantStore,
         makeScheduler: @escaping (Decimal) -> any NotificationScheduling = { UserNotificationScheduler(funMoney: $0) }) {
        self.store = store
        self.makeScheduler = makeScheduler
    }

    func refresh(requestingPermission: Bool) {
        let store = store
        let scheduler = makeScheduler(store.effectiveSettings.funMoney)
        Task {
            if requestingPermission {
                guard await scheduler.requestAuthorizationIfNeeded() else { return }
            }
            let settings = store.effectiveSettings
            let nextPayday = store.payday.nextPayday
            let cooling = store.cooling
            let thawing = cooling.filter { $0.price >= settings.timerThreshold && $0.thawsAt <= nextPayday }
            let total = thawing.reduce(Decimal(0)) { $0 + $1.price }

            await scheduler.cancelAll()
            if !thawing.isEmpty {
                await scheduler.schedulePaydayReview(at: nextPayday, thawingCount: thawing.count, total: total)
            }
            for want in cooling where want.price < settings.timerThreshold && want.thawsAt > .now {
                await scheduler.scheduleTimerThaw(wantID: want.id, name: want.name, at: want.thawsAt)
            }
        }
    }
}
