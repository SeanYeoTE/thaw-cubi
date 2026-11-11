import Foundation

final class PaydaySetupInteractor: PaydaySetupInteractorProtocol {
    weak var output: PaydaySetupInteractorOutput?
    private let store: WantStore
    private let reminders: Reminders
    private var observer: DataChangeObserver?

    // Explicit deinit: the synthesized one on a MainActor class with weak refs corrupts the heap in the test host.
    deinit {}

    init(store: WantStore, reminders: Reminders) {
        self.store = store
        self.reminders = reminders
        observer = DataChangeObserver { [weak self] in self?.output?.settingsDidChange() }
    }

    var settings: PaydaySettings { store.effectiveSettings }

    func save(_ settings: PaydaySettings, requestingPermission: Bool) {
        store.save(settings: settings)
        reminders.refresh(requestingPermission: requestingPermission)
        DataChange.post()
    }
}
