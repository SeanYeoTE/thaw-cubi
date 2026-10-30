import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        ThawAppearance.apply()
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = RootTabBarController(store: .shared)
        window.makeKeyAndVisible()
        self.window = window
    }
}
