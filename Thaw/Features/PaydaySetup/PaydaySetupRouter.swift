import UIKit

final class PaydaySetupRouter: PaydaySetupRouterProtocol {
    weak var viewController: UIViewController?
    private let onSaved: (() -> Void)?

    init(onSaved: (() -> Void)?) {
        self.onSaved = onSaved
    }

    /// Full-screen onboarding when `onSaved` is set, the Settings tab otherwise.
    static func createModule(store: WantStore, reminders: Reminders, onSaved: (() -> Void)? = nil) -> UIViewController {
        let view = PaydaySetupViewController()
        let router = PaydaySetupRouter(onSaved: onSaved)
        let interactor = PaydaySetupInteractor(store: store, reminders: reminders)
        let presenter = PaydaySetupPresenter(view: view, interactor: interactor, router: router)
        view.presenter = presenter
        router.viewController = view
        return view
    }

    var isOnboarding: Bool { onSaved != nil }

    func finishOnboarding() {
        onSaved?()
    }
}
