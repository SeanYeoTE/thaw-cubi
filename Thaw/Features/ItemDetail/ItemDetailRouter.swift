import UIKit

final class ItemDetailRouter: ItemDetailRouterProtocol {
    weak var viewController: UIViewController?
    private let store: WantStore
    private let reminders: Reminders
    var onEdited: (() -> Void)?

    // Explicit deinit: the synthesized one on a MainActor class with weak refs corrupts the heap in the test host.
    deinit {}

    init(store: WantStore, reminders: Reminders) {
        self.store = store
        self.reminders = reminders
    }

    static func createModule(store: WantStore, reminders: Reminders, wantID: UUID) -> UIViewController? {
        guard let want = store.want(id: wantID) else { return nil }
        let view = ItemDetailViewController()
        let router = ItemDetailRouter(store: store, reminders: reminders)
        let interactor = ItemDetailInteractor(store: store, reminders: reminders, want: want)
        let presenter = ItemDetailPresenter(view: view, interactor: interactor, router: router)
        view.presenter = presenter
        router.onEdited = { [weak presenter] in presenter?.didEdit() }
        router.viewController = view
        return view
    }

    func showDecideNow(want: Want) {
        let module = StillWantItRouter.createModule(store: store, reminders: reminders, wants: [want]) { [weak self] in
            self?.pop()
        }
        viewController?.present(ReviewSheet.wrap(module), animated: true)
    }

    func showEdit(wantID: UUID) {
        let module = AddWantRouter.createModule(store: store, reminders: reminders, editing: wantID) { [weak self] in
            self?.onEdited?()
        }
        viewController?.present(UINavigationController(rootViewController: module), animated: true)
    }

    func pop() {
        viewController?.navigationController?.popViewController(animated: true)
    }
}
