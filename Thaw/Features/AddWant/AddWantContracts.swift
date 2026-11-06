import Foundation

struct AddWantInput: Equatable {
    var name: String
    var price: String
    var reason: String
}

struct AddWantScreen: Equatable {
    let title: String
    let actionTitle: String
    let discardTitle: String
    let discardMessage: String
    let initial: AddWantInput?
    /// Read-only line above the form, e.g. "From example.com" for a shared page.
    var caption: String? = nil
}

/// Prefill for a want captured outside the app (the share sheet). The link is kept but not editable.
struct AddWantDraft: Equatable {
    var name: String
    var link: URL?
}

protocol AddWantViewProtocol: AnyObject {
    func configure(_ screen: AddWantScreen)
    func render(note: String)
    func setModalInPresentation(_ isModal: Bool)
    func showError(_ message: String)
    func showDiscardConfirmation()
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
}

protocol AddWantInteractorProtocol: AnyObject {
    var settings: PaydaySettings { get }
    /// Non-nil when editing an existing want instead of adding one.
    var editing: Want? { get }
    /// Non-nil when adding a want prefilled from the share sheet; `add` attaches its link.
    var draft: AddWantDraft? { get }
    func add(name: String, price: Decimal, reason: String)
    func save(name: String, price: Decimal, reason: String)
}

protocol AddWantRouterProtocol: AnyObject {
    func dismiss()
}
