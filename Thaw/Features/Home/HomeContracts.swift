import Foundation

enum CoolingFilter: String, CaseIterable {
    case all, payday, quickThaw
}

enum CoolingSort: String, CaseIterable {
    case soonest, priceHigh, recent, name
}

struct HomeCardViewModel: Equatable {
    let id: UUID
    let name: String
    let priceText: String
    let progress: Double
    let isTimer: Bool
    /// `timer` for quick thaws, `calendar` for payday wants.
    let symbol: String
    let trailingText: String
    let accessibilityLabel: String
    let accessibilityValue: String
}

struct HomeSectionViewModel: Equatable {
    /// nil draws no header.
    let title: String?
    let trailing: String?
    let cards: [HomeCardViewModel]
}

struct HomeSortOptionViewModel: Equatable {
    let sort: CoolingSort
    let title: String
    let isSelected: Bool
}

enum HomeEmptyKind: Equatable {
    /// Nothing is cooling: Cubi, one line and an add button.
    case noWants
    /// The filter hides every want: one line and a quiet reset button.
    case noMatches
}

struct HomeEmptyViewModel: Equatable {
    let kind: HomeEmptyKind
    let line: String
    let actionTitle: String
}

struct HomeViewModel {
    let filterTitles: [String]
    let filterIndex: Int
    let sortTitle: String
    let sortOptions: [HomeSortOptionViewModel]
    let sections: [HomeSectionViewModel]
    let empty: HomeEmptyViewModel?
    /// Every cooling want in the current sort, ignoring the filter.
    let cards: [HomeCardViewModel]
}

struct HomeSnapshot {
    let cooling: [Want]
    let payday: PaydaySchedule
    let settings: PaydaySettings
}

struct HomeDeleteConfirmation: Equatable {
    let title: String
    let message: String
    let deleteTitle: String
    let cancelTitle: String
}

protocol HomeViewProtocol: AnyObject {
    func render(_ model: HomeViewModel)
    /// Asks before deleting; confirming calls `confirmDelete(id:)`.
    func showDeleteConfirmation(id: UUID, confirmation: HomeDeleteConfirmation)
}

protocol HomePresenterProtocol: AnyObject {
    func viewWillAppear()
    func tapAdd()
    func tapWant(id: UUID)
    func tapEdit(id: UUID)
    func tapDelete(id: UUID)
    func confirmDelete(id: UUID)
    func selectFilter(at index: Int)
    func selectSort(_ sort: CoolingSort)
    func tapShowAll()
}

protocol HomeInteractorProtocol: AnyObject {
    var output: HomeInteractorOutput? { get set }
    /// Remembered across launches.
    var filter: CoolingFilter { get set }
    /// Remembered across launches.
    var sort: CoolingSort { get set }
    func snapshot() -> HomeSnapshot
    func delete(_ id: UUID)
}

protocol HomeInteractorOutput: AnyObject {
    func dataDidChange()
}

protocol HomeRouterProtocol: AnyObject {
    func showAddWant()
    func showItemDetail(id: UUID)
    func showEdit(id: UUID)
}
