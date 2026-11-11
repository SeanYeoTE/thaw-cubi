import UIKit

final class RootTabBarController: UITabBarController {
    enum Tab: Int, CaseIterable {
        case cooling, payday, stats, settings
    }

    private let store: WantStore
    private var observer: DataChangeObserver?
    private var timeChangeToken: NSObjectProtocol?
    private var thawTimer: Timer?

    init(store: WantStore, reminders: Reminders) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
        tabBar.tintColor = Theme.accent

        let cooling = UINavigationController(rootViewController: HomeRouter.createModule(store: store, reminders: reminders))
        cooling.tabBarItem = UITabBarItem(title: "Cooling", image: UIImage(systemName: "snowflake"), tag: Tab.cooling.rawValue)

        let payday = UINavigationController(rootViewController: PaydayRouter.createModule(store: store, reminders: reminders))
        payday.tabBarItem = UITabBarItem(title: "Payday", image: UIImage(systemName: "calendar"), tag: Tab.payday.rawValue)

        let saved = UINavigationController(rootViewController: SavedRouter.createModule(store: store, reminders: reminders))
        saved.tabBarItem = UITabBarItem(title: "Stats", image: UIImage(systemName: "chart.bar"), tag: Tab.stats.rawValue)

        let settings = UINavigationController(rootViewController: PaydaySetupRouter.createModule(store: store, reminders: reminders))
        settings.tabBarItem = UITabBarItem(title: "Settings", image: UIImage(systemName: "gearshape"), tag: Tab.settings.rawValue)

        viewControllers = [cooling, payday, saved, settings]

        observer = DataChangeObserver { [weak self] in self?.refreshBadge() }
        timeChangeToken = NotificationCenter.default.addObserver(
            forName: UIApplication.significantTimeChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshBadge() }
        }
        // Set at init so the badge is right at cold launch, before the Payday tab has loaded.
        refreshBadge()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func select(_ tab: Tab) {
        selectedIndex = tab.rawValue
    }

    /// Payday badge: wants ready to review. Also rearms a timer for the next timer thaw, since that changes
    /// the count with no data change.
    func refreshBadge() {
        let now = Date.now
        let ready = PaydayReadiness.ready(queue: store.reviewQueue, now: now)
        viewControllers?[Tab.payday.rawValue].tabBarItem.badgeValue = PaydayReadiness.badgeValue(readyCount: ready.count)

        thawTimer?.invalidate()
        thawTimer = nil
        guard let next = PaydayReadiness.nextThaw(cooling: store.cooling, now: now) else { return }
        let timer = Timer(fire: next.addingTimeInterval(1), interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshBadge() }
        }
        RunLoop.main.add(timer, forMode: .common)
        thawTimer = timer
    }
}
