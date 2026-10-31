import UIKit
import UserNotifications

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    let store = WantStore.launch(arguments: ProcessInfo.processInfo.arguments)
    private(set) lazy var reminders = Reminders(store: store)
    private(set) lazy var router = ReviewRouter(store: store, reminders: reminders)
    private var actionHandler: NotificationActionHandler?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let router = router
        let handler = NotificationActionHandler(
            scheduler: UserNotificationScheduler(funMoney: store.effectiveSettings.funMoney),
            store: store,
            onRoute: { _ in router.requestReview() }
        )
        actionHandler = handler
        UNUserNotificationCenter.current().delegate = handler
        return true
    }
}
