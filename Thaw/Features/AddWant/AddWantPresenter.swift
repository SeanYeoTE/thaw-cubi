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

    private var initial: AddWantInput?

    func viewDidLoad() {
        let settings = interactor.settings
        if let want = interactor.editing {
            let input = AddWantInput(name: want.name, price: Self.priceText(want.price), reason: want.reason)
            initial = input
            view?.configure(AddWantScreen(title: "Edit want", actionTitle: "Save", discardTitle: "Discard changes?",
                                          discardMessage: "Your edits won't be saved.", initial: input))
            view?.render(note: "You can change the name, price and reason. Moving the price across \(Formatting.sgd(settings.timerThreshold)) "
                + "restarts the wait from today: \(settings.timerDays)-day timer below it, payday above it.")
            return
        }
        view?.configure(AddWantScreen(title: "Add to Thaw", actionTitle: "Add to Thaw", discardTitle: "Discard this want?",
                                      discardMessage: "What you typed won't be saved.", initial: nil))
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
        saving = true
        view?.setModalInPresentation(false)
        if initial != nil {
            interactor.save(name: name, price: price, reason: input.reason)
            return router.dismiss()
        }
        interactor.add(name: name, price: price, reason: input.reason)
        view?.showSavedMoment(line: CubiMood.frozen.line) { [weak self] in self?.router.dismiss() }
    }

    private func discardOrDismiss(_ input: AddWantInput) {
        if hasInput(input) { view?.showDiscardConfirmation() } else { router.dismiss() }
    }

    private static func priceText(_ price: Decimal) -> String {
        NSDecimalNumber(decimal: price).stringValue
    }

    private func hasInput(_ input: AddWantInput) -> Bool {
        if let initial { return normalized(input) != normalized(initial) }
        return [input.name, input.price, input.reason].contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func normalized(_ input: AddWantInput) -> AddWantInput {
        AddWantInput(name: input.name.trimmingCharacters(in: .whitespacesAndNewlines),
                     price: input.price.trimmingCharacters(in: .whitespacesAndNewlines),
                     reason: input.reason.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
