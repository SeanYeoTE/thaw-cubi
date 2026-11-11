import UIKit

final class PaydayRouter: PaydayRouterProtocol {
    weak var viewController: UIViewController?
    private let store: WantStore
    private let reminders: Reminders

    // Explicit deinit: the synthesized one on a MainActor class with weak refs corrupts the heap in the test host.
    deinit {}

    init(store: WantStore, reminders: Reminders) {
        self.store = store
        self.reminders = reminders
    }

    static func createModule(store: WantStore, reminders: Reminders) -> UIViewController {
        let view = PaydayViewController()
        let router = PaydayRouter(store: store, reminders: reminders)
        let interactor = PaydayInteractor(store: store, reminders: reminders)
        let presenter = PaydayPresenter(view: view, interactor: interactor, router: router)
        view.presenter = presenter
        router.viewController = view
        return view
    }

    func showReview(wants: [Want]) {
        guard let viewController else { return }
        let module = PaydayReviewRouter.createModule(store: store, reminders: reminders, wants: wants) {
            [weak viewController] in
            viewController?.dismiss(animated: true)
        }
        viewController.present(ReviewSheet.wrap(module), animated: true)
    }

    func showItemDetail(id: UUID) {
        guard let module = ItemDetailRouter.createModule(store: store, reminders: reminders, wantID: id) else { return }
        viewController?.navigationController?.pushViewController(module, animated: true)
    }
}
