import UIKit

final class PaydaySetupRouter: PaydaySetupRouterProtocol, SettingsRouterProtocol {
    weak var viewController: UIViewController?
    private let store: WantStore
    private let reminders: Reminders
    private let onSaved: (() -> Void)?

    // Explicit deinit: the synthesized one on a MainActor class with weak refs corrupts the heap in the test host.
    deinit {}

    init(store: WantStore, reminders: Reminders, onSaved: (() -> Void)?) {
        self.store = store
        self.reminders = reminders
        self.onSaved = onSaved
    }

    /// Full-screen onboarding when `onSaved` is set, the Settings tab otherwise.
    static func createModule(store: WantStore, reminders: Reminders, onSaved: (() -> Void)? = nil) -> UIViewController {
        let router = PaydaySetupRouter(store: store, reminders: reminders, onSaved: onSaved)
        let interactor = PaydaySetupInteractor(store: store, reminders: reminders)
        if onSaved != nil {
            let view = PaydaySetupViewController()
            let presenter = PaydaySetupPresenter(view: view, interactor: interactor, router: router)
            view.presenter = presenter
            router.viewController = view
            return view
        }
        let view = SettingsViewController()
        let presenter = SettingsPresenter(view: view, interactor: interactor, router: router)
        interactor.output = presenter
        view.presenter = presenter
        router.viewController = view
        return view
    }

    static func createRuleScreen(store: WantStore, reminders: Reminders) -> UIViewController {
        let view = PaydayRuleViewController()
        let interactor = PaydaySetupInteractor(store: store, reminders: reminders)
        let presenter = PaydayRulePresenter(view: view, interactor: interactor)
        interactor.output = presenter
        view.presenter = presenter
        return view
    }

    func finishOnboarding() {
        onSaved?()
    }

    func showPaydayRule() {
        let rule = Self.createRuleScreen(store: store, reminders: reminders)
        viewController?.navigationController?.pushViewController(rule, animated: true)
    }
}
