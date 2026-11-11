import Foundation

final class PaydayInteractor: PaydayInteractorProtocol {
    weak var output: PaydayInteractorOutput?
    private let store: WantStore
    private let reminders: Reminders
    private var observer: DataChangeObserver?
    private var clockTokens: [NSObjectProtocol] = []
    private var thawTimer: Timer?

    // Explicit deinit: the synthesized one on a MainActor class with weak refs corrupts the heap in the test host.
    // Observers and the timer only hold `self` weakly, so leftovers after deinit are inert.
    deinit {}

    init(store: WantStore, reminders: Reminders) {
        self.store = store
        self.reminders = reminders
        observer = DataChangeObserver { [weak self] in self?.changed() }
        // Timers thaw by date, so readiness also changes when the clock or day moves.
        clockTokens = [Notification.Name.NSSystemClockDidChange, .NSCalendarDayChanged].map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.changed() }
            }
        }
        scheduleNextThaw()
    }

    func snapshot() -> PaydaySnapshot {
        PaydaySnapshot(cooling: store.cooling, reviewQueue: store.reviewQueue,
                       payday: store.payday, settings: store.effectiveSettings, now: .now)
    }

    func remindTonight(completion: @escaping () -> Void) {
        reminders.remindTonight(completion: completion)
    }

    private func changed() {
        scheduleNextThaw()
        output?.dataDidChange()
    }

    private func scheduleNextThaw() {
        thawTimer?.invalidate()
        thawTimer = nil
        guard let date = PaydayReadiness.nextThaw(cooling: store.cooling, now: .now) else { return }
        let timer = Timer(fire: date.addingTimeInterval(1), interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.changed() }
        }
        RunLoop.main.add(timer, forMode: .common)
        thawTimer = timer
    }
}
