import Foundation

final class PaydaySetupInteractor: PaydaySetupInteractorProtocol {
    private let store: WantStore
    private let reminders: Reminders

    init(store: WantStore, reminders: Reminders) {
        self.store = store
        self.reminders = reminders
    }

    var settings: PaydaySettings { store.effectiveSettings }

    func save(_ settings: PaydaySettings) {
        store.save(settings: settings)
        reminders.refresh(requestingPermission: true)
    }
}
