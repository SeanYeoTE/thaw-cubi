import UIKit

final class HomeRouter: HomeRouterProtocol {
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
        let view = HomeViewController()
        let router = HomeRouter(store: store, reminders: reminders)
        let interactor = HomeInteractor(store: store, reminders: reminders)
        let presenter = HomePresenter(view: view, interactor: interactor, router: router)
        view.presenter = presenter
        router.viewController = view
        return view
    }

    func showAddWant() {
        let module = AddWantRouter.createModule(store: store, reminders: reminders)
        viewController?.present(UINavigationController(rootViewController: module), animated: true)
    }

    func showEdit(id: UUID) {
        let module = AddWantRouter.createModule(store: store, reminders: reminders, editing: id)
        viewController?.present(UINavigationController(rootViewController: module), animated: true)
    }

    func showPaydayPreview() {
        let module = PaydayPreviewRouter.createModule(store: store, reminders: reminders)
        viewController?.present(UINavigationController(rootViewController: module), animated: true)
    }

    func showItemDetail(id: UUID) {
        guard let module = ItemDetailRouter.createModule(store: store, reminders: reminders, wantID: id) else { return }
        viewController?.navigationController?.pushViewController(module, animated: true)
    }
}
