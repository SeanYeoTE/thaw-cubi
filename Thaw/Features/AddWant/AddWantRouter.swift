import UIKit

final class AddWantRouter: AddWantRouterProtocol {
    weak var viewController: UIViewController?

    private let onFinish: (() -> Void)?

    // Explicit deinit: the synthesized one on a MainActor class with weak refs corrupts the heap in the test host.
    deinit {}

    init(onFinish: (() -> Void)? = nil) {
        self.onFinish = onFinish
    }

    /// Pass `editing` to edit an existing want; `onFinish` runs after the sheet is dismissed.
    static func createModule(store: WantStore, reminders: Reminders, editing wantID: UUID? = nil,
                             onFinish: (() -> Void)? = nil) -> UIViewController {
        let view = AddWantViewController()
        let router = AddWantRouter(onFinish: onFinish)
        let interactor = AddWantInteractor(store: store, reminders: reminders, editingID: wantID)
        let presenter = AddWantPresenter(view: view, interactor: interactor, router: router)
        view.presenter = presenter
        router.viewController = view
        return view
    }

    func dismiss() {
        viewController?.dismiss(animated: true, completion: onFinish)
    }
}
