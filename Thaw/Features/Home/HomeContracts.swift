import Foundation

struct HomeCardViewModel: Equatable {
    let id: UUID
    let name: String
    let priceText: String
    let progress: Double
    let isTimer: Bool
    let statusText: String
    let trailingText: String
}

struct HomeViewModel {
    let daysLeft: Int
    let nextPaydayText: String
    let paydaySubtitle: String
    let hasReview: Bool
    let cards: [HomeCardViewModel]
    let emptyText: String?
}

struct HomeSnapshot {
    let cooling: [Want]
    let reviewQueue: [Want]
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
    func tapPayday()
    func tapWant(id: UUID)
    func tapEdit(id: UUID)
    func tapDelete(id: UUID)
    func confirmDelete(id: UUID)
}

protocol HomeInteractorProtocol: AnyObject {
    var output: HomeInteractorOutput? { get set }
    func snapshot() -> HomeSnapshot
    func delete(_ id: UUID)
}

protocol HomeInteractorOutput: AnyObject {
    func dataDidChange()
}

protocol HomeRouterProtocol: AnyObject {
    func showAddWant()
    func showPaydayPreview()
    func showItemDetail(id: UUID)
    func showEdit(id: UUID)
}
