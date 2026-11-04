import Foundation

final class AddWantInteractor: AddWantInteractorProtocol {
    private let store: WantStore
    private let reminders: Reminders

    init(store: WantStore, reminders: Reminders) {
        self.store = store
        self.reminders = reminders
    }

    var settings: PaydaySettings { store.effectiveSettings }

    func add(name: String, price: Decimal, reason: String) {
        store.add(name: name, price: price, reason: reason)
        reminders.refresh(requestingPermission: true)
        DataChange.post()
    }
}
