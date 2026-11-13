import UIKit

/// What a notification route opens, decided without UIKit so it can be unit tested.
nonisolated enum ReviewDestination: Equatable {
    /// Payday tab, then the review of these wants.
    case review([Want])
    /// Payday tab, then the "Nothing to review right now" alert.
    case nothingToReview
    /// Payday tab, then that thawed want's "Still want it?" (D7).
    case stillWantIt(Want)
    /// Payday tab, then Item detail for a want that's already decided or not thawed yet (D7).
    case itemDetail(UUID)

    @MainActor static func resolve(_ route: NotificationRoute, store: WantStore, now: Date = .now) -> ReviewDestination {
        switch route {
        case .review:
            let wants = store.reviewQueue
            return wants.isEmpty ? .nothingToReview : .review(wants)
        case .want(let id):
            // A deleted want falls back to the review, so the tap still lands somewhere useful.
            guard let want = store.want(id: id) else { return resolve(.review, store: store, now: now) }
            return want.status == .cooling && want.thawsAt <= now ? .stillWantIt(want) : .itemDetail(id)
        }
    }
}

/// Holds a route until the tabs exist (cold launch, onboarding). The latest request wins.
nonisolated struct PendingRoute: Equatable {
    private(set) var route: NotificationRoute?

    mutating func request(_ route: NotificationRoute) {
        self.route = route
    }

    /// The held route once the tabs are ready, clearing it; nil while not ready or when nothing is held.
    mutating func take(isReady: Bool) -> NotificationRoute? {
        guard isReady, let route else { return nil }
        self.route = nil
        return route
    }
}

/// Opens what a tapped notification asks for on the Payday tab, holding the request until the tabs exist.
final class ReviewRouter {
    private let store: WantStore
    private let reminders: Reminders
    private var pending = PendingRoute()
    weak var window: UIWindow?

    init(store: WantStore, reminders: Reminders) {
        self.store = store
        self.reminders = reminders
    }

    func requestReview() {
        request(.review)
    }

    func request(_ route: NotificationRoute) {
        pending.request(route)
        presentIfPossible()
    }

    func presentIfPossible() {
        let tabs = window?.rootViewController as? RootTabBarController
        guard let route = pending.take(isReady: tabs != nil), let tabs else { return }
        let destination = ReviewDestination.resolve(route, store: store)
        let show = { [self] in present(destination, on: tabs) }
        if tabs.presentedViewController != nil {
            tabs.dismiss(animated: false, completion: show)
        } else {
            show()
        }
    }

    private func present(_ destination: ReviewDestination, on tabs: RootTabBarController) {
        // Land on Payday so whatever opens leaves the user on the Payday tab.
        tabs.select(.payday)
        let nav = tabs.selectedViewController as? UINavigationController
        nav?.popToRootViewController(animated: false)
        switch destination {
        case .nothingToReview:
            let alert = UIAlertController(title: "Nothing to review right now",
                                          message: "Your payday wants are already decided.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            tabs.present(alert, animated: true)
        case .review(let wants):
            let review = PaydayReviewRouter.createModule(store: store, reminders: reminders, wants: wants) { [weak tabs] in
                tabs?.dismiss(animated: true)
            }
            tabs.present(ReviewSheet.wrap(review), animated: true)
        case .stillWantIt(let want):
            let module = StillWantItRouter.createModule(store: store, reminders: reminders, wants: [want])
            tabs.present(ReviewSheet.wrap(module), animated: true)
        case .itemDetail(let id):
            guard let module = ItemDetailRouter.createModule(store: store, reminders: reminders, wantID: id) else { return }
            nav?.pushViewController(module, animated: false)
        }
    }
}
