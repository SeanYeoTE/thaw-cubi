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
        let show = { [self] in
            guard !wants.isEmpty else {
                let alert = UIAlertController(title: "Nothing to review right now",
                                              message: "Your payday wants are already decided.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                root.present(alert, animated: true)
                return
            }
            // Land on Home so the finished review leaves the user on the Cooling list.
            if let tabs = root as? UITabBarController {
                tabs.selectedIndex = 0
                (tabs.selectedViewController as? UINavigationController)?.popToRootViewController(animated: false)
            }
            let review = PaydayReviewViewController(store: store, reminders: reminders, wants: wants) { [weak root] in
                root?.dismiss(animated: true)
            }
            root.present(ReviewSheet.wrap(review), animated: true)
        }
        if root.presentedViewController != nil {
            root.dismiss(animated: false, completion: show)
        } else {
            show()
        }
    }
}
