import UIKit

final class RootTabBarController: UITabBarController {
    init(store: WantStore, reminders: Reminders) {
        super.init(nibName: nil, bundle: nil)
        tabBar.tintColor = Theme.accent

        let cooling = UINavigationController(rootViewController: HomeRouter.createModule(store: store, reminders: reminders))
        cooling.tabBarItem = UITabBarItem(title: "Cooling", image: UIImage(systemName: "snowflake"), tag: 0)

        let saved = UINavigationController(rootViewController: SavedRouter.createModule(store: store, reminders: reminders))
        saved.tabBarItem = UITabBarItem(title: "Stats", image: UIImage(systemName: "chart.bar"), tag: 1)

        let settings = UINavigationController(rootViewController: PaydaySetupRouter.createModule(store: store, reminders: reminders))
        settings.tabBarItem = UITabBarItem(title: "Settings", image: UIImage(systemName: "gearshape"), tag: 2)

        viewControllers = [cooling, saved, settings]
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}
