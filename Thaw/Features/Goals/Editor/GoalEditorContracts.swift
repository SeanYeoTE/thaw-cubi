import Foundation

struct GoalEditorInput: Equatable {
    var name: String
    var target: String
    var hasDeadline: Bool
    var deadline: Date
}

struct GoalEditorViewModel {
    let title: String
    let input: GoalEditorInput
    let minimumDate: Date
}

protocol GoalEditorViewProtocol: AnyObject {
    func render(_ model: GoalEditorViewModel)
    func setSaveEnabled(_ isEnabled: Bool)
    func setHint(_ text: String, isWarning: Bool)
    func setModalInPresentation(_ isModal: Bool)
    func showError(_ message: String)
    func showDiscardConfirmation()
}

protocol GoalEditorPresenterProtocol: AnyObject {
    func viewDidLoad()
    func inputChanged(_ input: GoalEditorInput)
    func tapClose(_ input: GoalEditorInput)
    func didAttemptDismiss(_ input: GoalEditorInput)
    func confirmDiscard()
    func tapSave(_ input: GoalEditorInput)
}

protocol GoalEditorInteractorProtocol: AnyObject {
    /// The goal being edited, nil when adding.
    var goal: Goal? { get }
    var funMoney: Decimal { get }
    var now: Date { get }
    /// Default deadline offered when the switch is turned on.
    var suggestedDeadline: Date { get }
    func save(name: String, target: Decimal, deadline: Date?) throws
}

protocol GoalEditorRouterProtocol: AnyObject {
    /// Dismisses the editor, then reports completion.
    func finish()
}
