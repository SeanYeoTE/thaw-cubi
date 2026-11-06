import Foundation

final class SavedInteractor: SavedInteractorProtocol {
    weak var output: SavedInteractorOutput?
    private let store: WantStore
    private let reminders: Reminders
    private var observer: DataChangeObserver?

    // Explicit deinit: the synthesized one on a MainActor class with weak refs corrupts the heap in the test host.
    deinit {}

    init(store: WantStore, reminders: Reminders) {
        self.store = store
        self.reminders = reminders
        observer = DataChangeObserver { [weak self] in self?.output?.dataDidChange() }
    }

    var wants: [Want] { store.wants }
    var funMoney: Decimal { store.effectiveSettings.funMoney }

    func delete(_ id: UUID) {
        store.delete(id)
        didMutate()
    }

    private func didMutate() {
        DataChange.post()
        reminders.refresh(requestingPermission: false)
    }
}
