import UIKit

/// Finishes the share request instead of dismissing a sheet: complete after a save, cancel otherwise.
final class ShareAddRouter: AddWantRouterProtocol {
    private weak var host: ShareViewController?
    private let interactor: ShareAddInteractor

    // Explicit deinit: the synthesized one on a MainActor class with weak refs corrupts the heap in the test host.
    deinit {}

    init(host: ShareViewController, interactor: ShareAddInteractor) {
        self.host = host
        self.interactor = interactor
    }

    static func createModule(host: ShareViewController, draft: AddWantDraft) -> UIViewController {
        let view = AddWantViewController()
        let interactor = ShareAddInteractor(draft: draft)
        let router = ShareAddRouter(host: host, interactor: interactor)
        let presenter = AddWantPresenter(view: view, interactor: interactor, router: router)
        view.presenter = presenter
        return UINavigationController(rootViewController: view)
    }

    func dismiss() {
        host?.finish(saved: interactor.didSave)
    }
}
