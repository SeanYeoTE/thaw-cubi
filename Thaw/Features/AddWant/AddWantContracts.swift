import Foundation

struct AddWantInput: Equatable {
    var name: String
    var price: String
    var reason: String
    /// The status picked in the Status row; nil when the form has no such row.
    var status: Want.Status? = nil
}

struct AddWantStatusOption: Equatable {
    let status: Want.Status
    let title: String
}

struct AddWantDeleteConfirmation: Equatable {
    let title: String
    let message: String
    let deleteTitle: String
    let cancelTitle: String
}

struct AddWantScreen: Equatable {
    let title: String
    let actionTitle: String
    let discardTitle: String
    let discardMessage: String
    let initial: AddWantInput?
    /// Read-only line above the form, e.g. "From example.com" for a shared page.
    var caption: String? = nil
    /// Choices for the Status row, only for decided wants being edited; empty hides the row.
    var statusOptions: [AddWantStatusOption] = []
    /// Title of the plain delete button at the bottom when editing; nil hides it.
    var deleteTitle: String? = nil
}

/// Prefill for a want captured outside the app (the share sheet). The link is kept but not editable.
struct AddWantDraft: Equatable {
    var name: String
    var link: URL?
}

protocol AddWantViewProtocol: AnyObject {
    func configure(_ screen: AddWantScreen)
    /// The quiet line under the price; nil hides it.
    func render(thawLine: String?)
    func setModalInPresentation(_ isModal: Bool)
    func showError(_ message: String)
    func showDiscardConfirmation()
    /// Asks before deleting; confirming calls `confirmDelete()`.
    func showDeleteConfirmation(_ confirmation: AddWantDeleteConfirmation)
    /// Ends editing, locks the bar buttons, shows the Cubi moment, then calls `completion` once.
    func showSavedMoment(line: String, completion: @escaping () -> Void)
}

protocol AddWantPresenterProtocol: AnyObject {
    func viewDidLoad()
    func inputChanged(_ input: AddWantInput)
    func tapCancel(_ input: AddWantInput)
    func didAttemptDismiss(_ input: AddWantInput)
    func confirmDiscard()
    func tapSave(_ input: AddWantInput)
    func tapDelete()
    func confirmDelete()
}

protocol AddWantInteractorProtocol: AnyObject {
    var settings: PaydaySettings { get }
    /// Non-nil when editing an existing want instead of adding one.
    var editing: Want? { get }
    /// Non-nil when adding a want prefilled from the share sheet; `add` attaches its link.
    var draft: AddWantDraft? { get }
    func add(name: String, price: Decimal, reason: String)
    func save(name: String, price: Decimal, reason: String)
    func moveBackToCooling()
    func setDecision(_ status: Want.Status)
    func deleteWant()
}

/// Only the app edits existing wants; the share extension adds, so these default to no-ops.
extension AddWantInteractorProtocol {
    func save(name: String, price: Decimal, reason: String) {}
    func moveBackToCooling() {}
    func setDecision(_ status: Want.Status) {}
    func deleteWant() {}
}

protocol AddWantRouterProtocol: AnyObject {
    func dismiss()
}
