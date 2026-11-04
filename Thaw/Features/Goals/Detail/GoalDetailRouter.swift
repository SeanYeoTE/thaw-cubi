import UIKit

final class GoalDetailRouter: GoalDetailRouterProtocol {
    weak var viewController: UIViewController?
    private let store: WantStore
    private let goalId: UUID

    // Explicit deinit: the synthesized one on a MainActor class with weak refs corrupts the heap in the test host.
    deinit {}

    init(store: WantStore, goalId: UUID) {
        self.store = store
        self.goalId = goalId
    }

    /// Meant to be pushed. Pops itself when the goal is archived, deleted or no longer exists.
    static func createModule(store: WantStore, goalId: UUID) -> UIViewController {
        let view = GoalDetailViewController()
        let router = GoalDetailRouter(store: store, goalId: goalId)
        let interactor = GoalDetailInteractor(store: store, goalId: goalId)
        let presenter = GoalDetailPresenter(view: view, interactor: interactor, router: router)
        interactor.output = presenter
        view.presenter = presenter
        router.viewController = view
        return view
    }

    func showEditor() {
        let module = GoalEditorRouter.createModule(store: store, goalId: goalId, onFinish: {})
        let nav = UINavigationController(rootViewController: module)
        nav.modalPresentationStyle = .formSheet
        viewController?.present(nav, animated: true)
    }

    func pop() {
        viewController?.navigationController?.popViewController(animated: true)
    }
}
