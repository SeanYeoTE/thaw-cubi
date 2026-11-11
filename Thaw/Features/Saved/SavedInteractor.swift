import Foundation

final class SavedInteractor: SavedInteractorProtocol {
    static let historyFilterKey = "stats.historyFilter"
    static let chartRangeKey = "stats.chartRange"

    weak var output: SavedInteractorOutput?
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

    var wants: [Want] { store.wants }
    var funMoney: Decimal { store.effectiveSettings.funMoney }

    var historyFilter: SavedHistoryFilter {
        get { defaults.string(forKey: Self.historyFilterKey).flatMap(SavedHistoryFilter.init(rawValue:)) ?? .all }
        set { defaults.set(newValue.rawValue, forKey: Self.historyFilterKey) }
    }

    var chartRange: SavedChartRange {
        get { defaults.string(forKey: Self.chartRangeKey).flatMap(SavedChartRange.init(rawValue:)) ?? .sixMonths }
        set { defaults.set(newValue.rawValue, forKey: Self.chartRangeKey) }
    }

    func delete(_ id: UUID) {
        store.delete(id)
        didMutate()
    }

    private func didMutate() {
        DataChange.post()
        reminders.refresh(requestingPermission: false)
    }
}
