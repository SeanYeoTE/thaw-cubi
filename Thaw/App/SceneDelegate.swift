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
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = store.settings == nil ? onboarding() : tabs()
        window.makeKeyAndVisible()
        self.window = window
        appDelegate?.router.window = window
        appDelegate?.router.presentIfPossible()
    }

    private func tabs() -> UIViewController {
        RootTabBarController(store: store, reminders: reminders)
    }

    private func onboarding() -> UIViewController {
        PaydaySetupViewController(store: store, reminders: reminders, onSaved: { [weak self] in
            guard let self, let window else { return }
            UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
                window.rootViewController = self.tabs()
            } completion: { _ in
                self.appDelegate?.router.presentIfPossible()
            }
        })
    }
}
