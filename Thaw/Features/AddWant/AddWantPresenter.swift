import Foundation

final class AddWantPresenter: AddWantPresenterProtocol {
    private weak var view: AddWantViewProtocol?
    private let interactor: AddWantInteractorProtocol
    private let router: AddWantRouterProtocol
    private var saving = false

    // Explicit deinit: the synthesized one on a MainActor class with weak refs corrupts the heap in the test host.
    deinit {}

    init(view: AddWantViewProtocol, interactor: AddWantInteractorProtocol, router: AddWantRouterProtocol) {
        self.view = view
        self.interactor = interactor
        self.router = router
    }

    func viewDidLoad() {
        let settings = interactor.settings
        view?.render(note: "Thaw will read this back to you when it thaws. Items under "
            + "\(Formatting.sgd(settings.timerThreshold)) use a \(settings.timerDays)-day timer; the rest thaw on payday.")
    }

    func inputChanged(_ input: AddWantInput) {
        view?.setModalInPresentation(hasInput(input) && !saving)
    }

    func tapCancel(_ input: AddWantInput) { discardOrDismiss(input) }

    func didAttemptDismiss(_ input: AddWantInput) { view?.showDiscardConfirmation() }

    func confirmDiscard() { router.dismiss() }

    func tapSave(_ input: AddWantInput) {
        let name = input.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return view?.showError("Add a name for the item.") ?? () }
        guard let price = Decimal(string: input.price), price > 0 else {
            return view?.showError("Enter a price above S$0.") ?? ()
        }
        interactor.add(name: name, price: price, reason: input.reason)
        saving = true
        view?.setModalInPresentation(false)
        view?.showSavedMoment(line: CubiMood.frozen.line) { [weak self] in self?.router.dismiss() }
    }

    private func discardOrDismiss(_ input: AddWantInput) {
        if hasInput(input) { view?.showDiscardConfirmation() } else { router.dismiss() }
    }

    private func hasInput(_ input: AddWantInput) -> Bool {
        [input.name, input.price, input.reason].contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}
