import Foundation

final class GoalEditorPresenter: GoalEditorPresenterProtocol {
    private weak var view: GoalEditorViewProtocol?
    private let interactor: GoalEditorInteractorProtocol
    private let router: GoalEditorRouterProtocol
    private var initial: GoalEditorInput
    private var saving = false

    // Explicit deinit: the synthesized one on a MainActor class with weak refs corrupts the heap in the test host.
    deinit {}

    init(view: GoalEditorViewProtocol, interactor: GoalEditorInteractorProtocol, router: GoalEditorRouterProtocol) {
        self.view = view
        self.interactor = interactor
        self.router = router
        let suggested = interactor.suggestedDeadline
        if let goal = interactor.goal {
            initial = GoalEditorInput(name: goal.name, target: Self.plain(goal.target),
                                      hasDeadline: goal.deadline != nil, deadline: goal.deadline ?? suggested)
        } else {
            initial = GoalEditorInput(name: "", target: "", hasDeadline: false, deadline: suggested)
        }
    }

    func viewDidLoad() {
        let isEditing = interactor.goal != nil
        view?.render(GoalEditorViewModel(title: isEditing ? "Edit goal" : "New goal", input: initial,
                                         minimumDate: interactor.now))
        inputChanged(initial)
    }

    func inputChanged(_ input: GoalEditorInput) {
        view?.setSaveEnabled(isValid(input))
        let target = parseTarget(input.target)
        let tooLow = target.map { !GoalLedger.validate(target: $0, funMoney: interactor.funMoney) } ?? false
        view?.setHint("Goals are for wants over \(Formatting.sgd(interactor.funMoney)), your monthly fun money.",
                      isWarning: tooLow)
        view?.setModalInPresentation(isEdited(input) && !saving)
    }

    func tapClose(_ input: GoalEditorInput) {
        if isEdited(input) { view?.showDiscardConfirmation() } else { router.finish() }
    }

    func didAttemptDismiss(_ input: GoalEditorInput) { view?.showDiscardConfirmation() }

    func confirmDiscard() { router.finish() }

    func tapSave(_ input: GoalEditorInput) {
        let name = input.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return view?.showError("Add a name for the goal.") ?? () }
        guard let target = parseTarget(input.target), GoalLedger.validate(target: target, funMoney: interactor.funMoney) else {
            return view?.showError("Set a target over \(Formatting.sgd(interactor.funMoney)).") ?? ()
        }
        do {
            try interactor.save(name: name, target: target, deadline: input.hasDeadline ? input.deadline : nil)
        } catch GoalError.emptyName {
            return view?.showError("Add a name for the goal.") ?? ()
        } catch {
            return view?.showError("Set a target over \(Formatting.sgd(interactor.funMoney)).") ?? ()
        }
        saving = true
        view?.setModalInPresentation(false)
        router.finish()
    }

    private func isValid(_ input: GoalEditorInput) -> Bool {
        guard !input.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let target = parseTarget(input.target) else { return false }
        return GoalLedger.validate(target: target, funMoney: interactor.funMoney)
    }

    private func isEdited(_ input: GoalEditorInput) -> Bool {
        normalized(input) != normalized(initial)
    }

    // The date only matters while the deadline switch is on.
    private func normalized(_ input: GoalEditorInput) -> GoalEditorInput {
        var copy = input
        copy.name = input.name.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.target = parseTarget(input.target).map(Self.plain) ?? input.target.trimmingCharacters(in: .whitespaces)
        if !copy.hasDeadline { copy.deadline = Date(timeIntervalSince1970: 0) }
        return copy
    }

    private func parseTarget(_ text: String) -> Decimal? {
        let cleaned = text.replacingOccurrences(of: "S$", with: "").replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard let value = Decimal(string: cleaned), value > 0 else { return nil }
        return value
    }

    private static func plain(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }
}
