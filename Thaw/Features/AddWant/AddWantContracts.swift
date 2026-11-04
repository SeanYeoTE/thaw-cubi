import Foundation

struct AddWantInput: Equatable {
    var name: String
    var price: String
    var reason: String
}

protocol AddWantViewProtocol: AnyObject {
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
    func add(name: String, price: Decimal, reason: String)
}

protocol AddWantRouterProtocol: AnyObject {
    func dismiss()
}
