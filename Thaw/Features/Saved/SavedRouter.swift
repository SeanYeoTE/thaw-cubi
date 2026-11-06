import UIKit

final class SavedRouter: SavedRouterProtocol {
    weak var viewController: UIViewController?
    private let store: WantStore
    private let reminders: Reminders

    init(store: WantStore, reminders: Reminders) {
        self.store = store
        self.reminders = reminders
    }

    // Explicit deinit: the synthesized one on a MainActor class with weak refs corrupts the heap in the test host.
    deinit {}

    static func createModule(store: WantStore, reminders: Reminders) -> UIViewController {
        let view = SavedViewController()
        let router = SavedRouter(store: store, reminders: reminders)
        let interactor = SavedInteractor(store: store, reminders: reminders)
        let presenter = SavedPresenter(view: view, interactor: interactor, router: router)
        view.presenter = presenter
        router.viewController = view
        return view
    }

    func showEdit(id: UUID) {
        let module = AddWantRouter.createModule(store: store, reminders: reminders, editing: id)
        viewController?.present(UINavigationController(rootViewController: module), animated: true)
    }
}
