import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    private var appDelegate: AppDelegate? { UIApplication.shared.delegate as? AppDelegate }
    private var store: WantStore { appDelegate?.store ?? .shared }
    private var reminders: Reminders { appDelegate?.reminders ?? Reminders(store: store) }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        ThawAppearance.apply()
        let window = UIWindow(windowScene: windowScene)
        window.tintColor = Theme.accent
        AppearanceMode.saved.apply(to: window)
        window.rootViewController = store.settings == nil ? onboarding() : tabs()
        window.makeKeyAndVisible()
        self.window = window
        appDelegate?.router.window = window
        appDelegate?.router.presentIfPossible()
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        appDelegate?.ingestSharedDrafts()
        (window?.rootViewController as? RootTabBarController)?.refreshBadge()
    }

    private func tabs() -> UIViewController {
        let tabs = RootTabBarController(store: store, reminders: reminders)
#if DEBUG
        // `-thawTab payday` opens on a given tab, for simulator checks and screenshots.
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-thawTab"), arguments.indices.contains(index + 1),
           let tab = RootTabBarController.Tab.allCases.first(where: { "\($0)" == arguments[index + 1] }) {
            tabs.select(tab)
        }
#endif
        return tabs
    }

    private func onboarding() -> UIViewController {
        PaydaySetupRouter.createModule(store: store, reminders: reminders, onSaved: { [weak self] in
            guard let self, let window else { return }
            UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
                window.rootViewController = self.tabs()
            } completion: { _ in
                self.appDelegate?.router.presentIfPossible()
            }
        })
    }
}
