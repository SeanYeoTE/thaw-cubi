import Foundation

final class HomeInteractor: HomeInteractorProtocol {
    weak var output: HomeInteractorOutput?
    private let store: WantStore
    private var observer: DataChangeObserver?

    // Explicit deinit: the synthesized one on a MainActor class with weak refs corrupts the heap in the test host.
    deinit {}

    init(store: WantStore) {
        self.store = store
        observer = DataChangeObserver { [weak self] in self?.output?.dataDidChange() }
    }

    func snapshot() -> HomeSnapshot {
        HomeSnapshot(cooling: store.cooling, reviewQueue: store.reviewQueue,
                     payday: store.payday, settings: store.effectiveSettings,
                     monthEnd: store.monthEndSummary)
    }

    func dismissMonthEndSummary() { store.dismissMonthEndSummary() }
}
