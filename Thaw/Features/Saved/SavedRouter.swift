import UIKit

final class SavedRouter: SavedRouterProtocol {
    weak var viewController: UIViewController?
    private let store: WantStore

    // Explicit deinit: the synthesized one on a MainActor class with weak refs corrupts the heap in the test host.
    deinit {}

    init(store: WantStore) {
        self.store = store
    }

    static func createModule(store: WantStore) -> UIViewController {
        let view = SavedViewController()
        let router = SavedRouter(store: store)
        let interactor = SavedInteractor(store: store)
        let presenter = SavedPresenter(view: view, interactor: interactor, router: router)
        view.presenter = presenter
        router.viewController = view
        return view
    }

    func showGoalDetail(id: UUID) {
        let module = GoalDetailRouter.createModule(store: store, goalId: id)
        viewController?.navigationController?.pushViewController(module, animated: true)
    }

    func showGoalEditor() {
        let module = GoalEditorRouter.createModule(store: store, goalId: nil, onFinish: {})
        let nav = UINavigationController(rootViewController: module)
        nav.modalPresentationStyle = .formSheet
        viewController?.present(nav, animated: true)
    }
}
