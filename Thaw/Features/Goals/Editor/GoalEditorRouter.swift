import UIKit

final class GoalEditorRouter: GoalEditorRouterProtocol {
    weak var viewController: UIViewController?
    private var onFinish: (() -> Void)?

    // Explicit deinit: the synthesized one on a MainActor class with weak refs corrupts the heap in the test host.
    deinit {}

    /// `goalId` nil adds a goal. The caller presents the result (wrapped in a navigation controller) and
    /// `onFinish` runs after the editor dismisses itself, whether saved or discarded.
    static func createModule(store: WantStore, goalId: UUID?, onFinish: @escaping () -> Void) -> UIViewController {
        let view = GoalEditorViewController()
        let router = GoalEditorRouter()
        router.onFinish = onFinish
        let interactor = GoalEditorInteractor(store: store, goalId: goalId)
        let presenter = GoalEditorPresenter(view: view, interactor: interactor, router: router)
        view.presenter = presenter
        router.viewController = view
        return view
    }

    func finish() {
        let completion = onFinish
        onFinish = nil
        viewController?.dismiss(animated: true) { completion?() }
    }
}
