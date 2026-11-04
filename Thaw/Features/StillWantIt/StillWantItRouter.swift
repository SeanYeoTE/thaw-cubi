import UIKit

final class StillWantItRouter: StillWantItRouterProtocol {
    weak var viewController: UIViewController?

    static func createModule(store: WantStore, reminders: Reminders, wants: [Want],
                             onFinish: (() -> Void)? = nil) -> UIViewController {
        let view = StillWantItViewController()
        let router = StillWantItRouter()
        let interactor = StillWantItInteractor(store: store, reminders: reminders, wants: wants)
        let presenter = StillWantItPresenter(view: view, interactor: interactor, router: router, onFinish: onFinish)
        view.presenter = presenter
        router.viewController = view
        return view
    }

    func dismiss(completion: (() -> Void)?) {
        viewController?.navigationController?.dismiss(animated: true, completion: completion)
    }
}
