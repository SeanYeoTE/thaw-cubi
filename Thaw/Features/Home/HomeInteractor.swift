import Foundation

final class HomeInteractor: HomeInteractorProtocol {
    static let filterKey = "cooling.filter"
    static let sortKey = "cooling.sort"

    weak var output: HomeInteractorOutput?
    private let store: WantStore
    private let reminders: Reminders
    private let defaults: UserDefaults
    private var observer: DataChangeObserver?

    // Explicit deinit: the synthesized one on a MainActor class with weak refs corrupts the heap in the test host.
    deinit {}

    init(store: WantStore, reminders: Reminders, defaults: UserDefaults = .standard) {
        self.store = store
        self.reminders = reminders
        self.defaults = defaults
        observer = DataChangeObserver { [weak self] in self?.output?.dataDidChange() }
    }

    var filter: CoolingFilter {
        get { defaults.string(forKey: Self.filterKey).flatMap(CoolingFilter.init(rawValue:)) ?? .all }
        set { defaults.set(newValue.rawValue, forKey: Self.filterKey) }
    }

    var sort: CoolingSort {
        get { defaults.string(forKey: Self.sortKey).flatMap(CoolingSort.init(rawValue:)) ?? .soonest }
        set { defaults.set(newValue.rawValue, forKey: Self.sortKey) }
    }

    func snapshot() -> HomeSnapshot {
        HomeSnapshot(cooling: store.cooling, payday: store.payday, settings: store.effectiveSettings)
    }

    func delete(_ id: UUID) {
        store.delete(id)
        reminders.refresh(requestingPermission: false)
        DataChange.post()
    }
}
