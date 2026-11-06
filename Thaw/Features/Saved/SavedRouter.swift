import UIKit

final class SavedRouter: SavedRouterProtocol {
    weak var viewController: UIViewController?

    // Explicit deinit: the synthesized one on a MainActor class with weak refs corrupts the heap in the test host.
    deinit {}

    static func createModule(store: WantStore, reminders: Reminders) -> UIViewController {
        let view = SavedViewController()
        let router = SavedRouter()
        let interactor = SavedInteractor(store: store, reminders: reminders)
        let presenter = SavedPresenter(view: view, interactor: interactor, router: router)
        view.presenter = presenter
        router.viewController = view
        return view
    }
}
