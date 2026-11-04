import UIKit

final class GoalCompleteRouter: GoalCompleteRouterProtocol {
    weak var viewController: UIViewController?
    private var onFinish: (() -> Void)?

    // Explicit deinit: the synthesized one on a MainActor class with weak refs corrupts the heap in the test host.
    deinit {}

    /// The caller presents the result (wrapped, e.g. with `ReviewSheet.wrap`); `onFinish` runs after it dismisses itself.
    static func createModule(store: WantStore, goalId: UUID, onFinish: @escaping () -> Void) -> UIViewController {
        let view = GoalCompleteViewController()
        let router = GoalCompleteRouter()
        router.onFinish = onFinish
        let interactor = GoalCompleteInteractor(store: store, goalId: goalId)
        let presenter = GoalCompletePresenter(view: view, interactor: interactor, router: router)
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
