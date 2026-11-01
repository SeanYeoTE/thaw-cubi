import UIKit

/// Opens the Payday review from a notification, holding the request until the tabs exist (cold launch, onboarding).
final class ReviewRouter {
    private let store: WantStore
    private let reminders: Reminders
    private var pending = false
    weak var window: UIWindow?

    init(store: WantStore, reminders: Reminders) {
        self.store = store
        self.reminders = reminders
    }

    func requestReview() {
        pending = true
        presentIfPossible()
    }

    func presentIfPossible() {
        guard pending, let root = window?.rootViewController, root is RootTabBarController else { return }
        pending = false
        let wants = store.reviewQueue
        guard !wants.isEmpty else { return }
        let show = {
            let review = PaydayReviewViewController(store: self.store, reminders: self.reminders, wants: wants)
            let nav = UINavigationController(rootViewController: review)
            nav.modalPresentationStyle = .fullScreen
            root.present(nav, animated: true)
        }
        if root.presentedViewController != nil {
            root.dismiss(animated: false, completion: show)
        } else {
            show()
        }
    }
}
