import Foundation

final class AddWantInteractor: AddWantInteractorProtocol {
    private let store: WantStore
    private let reminders: Reminders
    private let editingID: UUID?

    init(store: WantStore, reminders: Reminders, editingID: UUID? = nil) {
        self.store = store
        self.reminders = reminders
        self.editingID = editingID
    }

    var editing: Want? { editingID.flatMap { store.want(id: $0) } }

    var draft: AddWantDraft? { nil }

    var settings: PaydaySettings { store.effectiveSettings }

    func add(name: String, price: Decimal, reason: String) {
        store.add(name: name, price: price, reason: reason)
        reminders.refresh(requestingPermission: true)
        DataChange.post()
    }

    func save(name: String, price: Decimal, reason: String) {
        guard let editingID else { return }
        store.edit(editingID, name: name, price: price, reason: reason)
        reminders.refresh(requestingPermission: false)
        DataChange.post()
    }

    func moveBackToCooling() {
        guard let editingID else { return }
        store.reopen(editingID)
        didMutate()
    }

    func setDecision(_ status: Want.Status) {
        guard let editingID else { return }
        store.setDecision(editingID, to: status)
        didMutate()
    }

    func deleteWant() {
        guard let editingID else { return }
        store.delete(editingID)
        didMutate()
    }

    private func didMutate() {
        reminders.refresh(requestingPermission: false)
        DataChange.post()
    }
}
