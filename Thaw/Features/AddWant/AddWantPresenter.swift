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
    private var isEditing = false

    func viewDidLoad() {
        let settings = interactor.settings
        if let want = interactor.editing {
            let input = AddWantInput(name: want.name, price: Self.priceText(want.price), reason: want.reason)
            initial = input
            isEditing = true
            view?.configure(AddWantScreen(title: "Edit want", actionTitle: "Save", discardTitle: "Discard changes?",
                                          discardMessage: "Your edits won't be saved.", initial: input,
                                          actions: Self.actions(for: want.status)))
            view?.render(note: want.status == .cooling
                ? "You can change the name, price and reason. Moving the price across \(Formatting.sgd(settings.timerThreshold)) "
                    + "restarts the wait from today: \(settings.timerDays)-day timer below it, payday above it."
                : "You can change the name, price and reason. The price feeds your saved total and history.")
            return
        }
        if let draft = interactor.draft {
            let input = AddWantInput(name: draft.name, price: "", reason: "")
            initial = input
            view?.configure(AddWantScreen(title: "Add to Thaw", actionTitle: "Add to Thaw", discardTitle: "Discard this want?",
                                          discardMessage: "What you typed won't be saved.", initial: input,
                                          caption: draft.link.map { "From \(ShareItemParser.displayHost($0))" }))
            view?.render(note: "Thaw will read this back to you when it thaws. It joins your Cooling list "
                + "the next time you open Thaw.")
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
        guard let (name, price) = validated(input) else { return }
        saving = true
        view?.setModalInPresentation(false)
        if isEditing {
            interactor.save(name: name, price: price, reason: input.reason)
            return router.dismiss()
        }
        interactor.add(name: name, price: price, reason: input.reason)
        view?.showSavedMoment(line: CubiMood.frozen.line) { [weak self] in self?.router.dismiss() }
    }

    func tapAction(_ kind: AddWantAction.Kind, input: AddWantInput) {
        guard isEditing else { return }
        if kind == .delete {
            let name = interactor.editing?.name ?? "this want"
            return view?.showDeleteConfirmation(AddWantDeleteConfirmation(
                title: "Delete \(name)?",
                message: "It will be removed from Thaw, including your history and savings total.",
                deleteTitle: "Delete", cancelTitle: "Cancel")) ?? ()
        }
        // Details typed before choosing an action are kept, as long as they are valid.
        if let initial, normalized(input) != normalized(initial) {
            guard let (name, price) = validated(input) else { return }
            interactor.save(name: name, price: price, reason: input.reason)
        }
        switch kind {
        case .moveBackToCooling: interactor.moveBackToCooling()
        case .markBought: interactor.setDecision(.bought)
        case .markSkipped: interactor.setDecision(.skipped)
        case .delete: break
        }
        finishEditing()
    }

    func confirmDelete() {
        guard isEditing else { return }
        interactor.deleteWant()
        finishEditing()
    }

    private func finishEditing() {
        saving = true
        view?.setModalInPresentation(false)
        router.dismiss()
    }

    private func validated(_ input: AddWantInput) -> (String, Decimal)? {
        let name = input.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            view?.showError("Add a name for the item.")
            return nil
        }
        guard let price = Decimal(string: input.price), price > 0 else {
            view?.showError("Enter a price above S$0.")
            return nil
        }
        return (name, price)
    }

    private static func actions(for status: Want.Status) -> [AddWantAction] {
        switch status {
        case .cooling:
            [AddWantAction(kind: .delete, title: "Delete")]
        case .skipped:
            [AddWantAction(kind: .moveBackToCooling, title: "Move back to cooling"),
             AddWantAction(kind: .markBought, title: "Mark as bought"),
             AddWantAction(kind: .delete, title: "Delete")]
        case .bought:
            [AddWantAction(kind: .moveBackToCooling, title: "Move back to cooling"),
             AddWantAction(kind: .markSkipped, title: "Mark as skipped"),
             AddWantAction(kind: .delete, title: "Delete")]
        }
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
