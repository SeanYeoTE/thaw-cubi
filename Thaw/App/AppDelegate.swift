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
        ingestSharedDrafts()
        return true
    }

    /// Moves wants saved from the share sheet into the store (at launch and on every foreground).
    func ingestSharedDrafts(inbox: ShareInbox = .shared) {
        let drafts = inbox.pending()
        guard !drafts.isEmpty else { return }
        let added = store.ingest(drafts)
        inbox.remove(ids: Set(drafts.map(\.id)))
        guard added > 0 else { return }
        DataChange.post()
        reminders.refresh(requestingPermission: false)
    }
}
