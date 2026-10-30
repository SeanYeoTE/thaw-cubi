import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    private let store = WantStore.launch(arguments: ProcessInfo.processInfo.arguments)
    private lazy var reminders = Reminders(store: store)

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        ThawAppearance.apply()
        let window = UIWindow(windowScene: windowScene)
        window.tintColor = Theme.accent
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = store.settings == nil ? onboarding() : tabs()
        window.makeKeyAndVisible()
        self.window = window
    }

    private func tabs() -> UIViewController {
        RootTabBarController(store: store, reminders: reminders)
    }

    private func onboarding() -> UIViewController {
        PaydaySetupViewController(store: store, reminders: reminders, onSaved: { [weak self] in
            guard let self, let window else { return }
            UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
                window.rootViewController = self.tabs()
            }
        })
    }
}
