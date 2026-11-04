import UIKit

final class SavedRouter: SavedRouterProtocol {
    weak var viewController: UIViewController?

    static func createModule(store: WantStore) -> UIViewController {
        let view = SavedViewController()
        let router = SavedRouter()
        let interactor = SavedInteractor(store: store)
        let presenter = SavedPresenter(view: view, interactor: interactor, router: router)
        view.presenter = presenter
        router.viewController = view
        return view
    }
}
