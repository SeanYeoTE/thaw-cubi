import UIKit

final class PaydayReviewRouter: PaydayReviewRouterProtocol {
    weak var viewController: UIViewController?

    /// `onFinish` closes the whole flow after the choices are applied; without it the review dismisses itself.
    static func createModule(store: WantStore, reminders: Reminders, wants: [Want],
                             onFinish: (() -> Void)? = nil) -> UIViewController {
        let view = PaydayReviewViewController()
        let router = PaydayReviewRouter()
        let interactor = PaydayReviewInteractor(store: store, reminders: reminders, wants: wants)
        let presenter = PaydayReviewPresenter(view: view, interactor: interactor, router: router, onFinish: onFinish)
        view.presenter = presenter
        router.viewController = view
        return view
    }

    func dismiss() {
        viewController?.navigationController?.dismiss(animated: true)
    }
}
