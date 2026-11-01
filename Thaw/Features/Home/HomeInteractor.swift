import Foundation

final class HomeInteractor: HomeInteractorProtocol {
    weak var output: HomeInteractorOutput?
    private let store: WantStore
    private var observer: DataChangeObserver?

    init(store: WantStore) {
        self.store = store
        observer = DataChangeObserver { [weak self] in self?.output?.dataDidChange() }
    }

    func snapshot() -> HomeSnapshot {
        HomeSnapshot(cooling: store.cooling, reviewQueue: store.reviewQueue,
                     payday: store.payday, settings: store.effectiveSettings)
    }
}
