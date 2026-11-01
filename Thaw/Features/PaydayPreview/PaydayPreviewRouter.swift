import UIKit

final class PaydayPreviewRouter: PaydayPreviewRouterProtocol {
    weak var viewController: UIViewController?
    private let store: WantStore
    private let reminders: Reminders

    init(store: WantStore, reminders: Reminders) {
        self.store = store
        self.reminders = reminders
    }

    static func createModule(store: WantStore, reminders: Reminders) -> UIViewController {
        let view = PaydayPreviewViewController()
        let router = PaydayPreviewRouter(store: store, reminders: reminders)
        let interactor = PaydayPreviewInteractor(store: store, reminders: reminders)
        let presenter = PaydayPreviewPresenter(view: view, interactor: interactor, router: router)
        view.presenter = presenter
        router.viewController = view
        return view
    }

    func showReview(wants: [Want]) {
        // Finishing the review closes the preview as well, landing on the preview's presenter (Home).
        let presenter = viewController?.navigationController?.presentingViewController ?? viewController?.presentingViewController
        let module = PaydayReviewRouter.createModule(store: store, reminders: reminders, wants: wants) {
            presenter?.dismiss(animated: true)
        }
        viewController?.present(ReviewSheet.wrap(module), animated: true)
    }

    func dismiss() {
        viewController?.dismiss(animated: true)
    }
}
