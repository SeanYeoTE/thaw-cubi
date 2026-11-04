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
        let interactor = HomeInteractor(store: store)
        let presenter = HomePresenter(view: view, interactor: interactor, router: router)
        view.presenter = presenter
        router.viewController = view
        return view
    }

    func showAddWant() {
        let module = AddWantRouter.createModule(store: store, reminders: reminders)
        viewController?.present(UINavigationController(rootViewController: module), animated: true)
    }

    func showPaydayPreview() {
        let module = PaydayPreviewRouter.createModule(store: store, reminders: reminders)
        viewController?.present(UINavigationController(rootViewController: module), animated: true)
    }

    func showSaved(completedGoalId: UUID?) {
        guard let tabs = viewController?.tabBarController else { return }
        tabs.selectedIndex = 1
        guard let goalId = completedGoalId else { return }
        let module = GoalCompleteRouter.createModule(store: store, goalId: goalId, onFinish: {})
        let nav = UINavigationController(rootViewController: module)
        nav.modalPresentationStyle = .fullScreen
        tabs.present(nav, animated: true)
    }

    func showItemDetail(id: UUID) {
        guard let module = ItemDetailRouter.createModule(store: store, reminders: reminders, wantID: id) else { return }
        viewController?.navigationController?.pushViewController(module, animated: true)
    }
}
