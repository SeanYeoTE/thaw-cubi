import UIKit

final class AddWantRouter: AddWantRouterProtocol {
    weak var viewController: UIViewController?

    static func createModule(store: WantStore, reminders: Reminders) -> UIViewController {
        let view = AddWantViewController()
        let router = AddWantRouter()
        let interactor = AddWantInteractor(store: store, reminders: reminders)
        let presenter = AddWantPresenter(view: view, interactor: interactor, router: router)
        view.presenter = presenter
        router.viewController = view
        return view
    }

    func dismiss() {
        viewController?.dismiss(animated: true)
    }
}
