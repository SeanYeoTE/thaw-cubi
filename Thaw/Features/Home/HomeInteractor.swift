import Foundation

final class HomeInteractor: HomeInteractorProtocol {
    weak var output: HomeInteractorOutput?
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

    func snapshot() -> HomeSnapshot {
        HomeSnapshot(cooling: store.cooling, reviewQueue: store.reviewQueue,
                     payday: store.payday, settings: store.effectiveSettings)
    }

    func delete(_ id: UUID) {
        store.delete(id)
        reminders.refresh(requestingPermission: false)
        DataChange.post()
    }
}
