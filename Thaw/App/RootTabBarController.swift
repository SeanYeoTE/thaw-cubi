import UIKit

final class RootTabBarController: UITabBarController {
    init(store: WantStore) {
        super.init(nibName: nil, bundle: nil)
        tabBar.tintColor = Theme.accent

        let cooling = UINavigationController(rootViewController: HomeViewController(store: store))
        cooling.tabBarItem = UITabBarItem(title: "Cooling", image: UIImage(systemName: "snowflake"), tag: 0)

        let saved = UINavigationController(rootViewController: SavedViewController(store: store))
        saved.tabBarItem = UITabBarItem(title: "Saved", image: UIImage(systemName: "chart.bar"), tag: 1)

        let settings = UINavigationController(rootViewController: SettingsViewController())
        settings.tabBarItem = UITabBarItem(title: "Settings", image: UIImage(systemName: "gearshape"), tag: 2)

        viewControllers = [cooling, saved, settings]
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}
