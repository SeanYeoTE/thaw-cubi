import Foundation

struct HomeCardViewModel: Equatable {
    let id: UUID
    let name: String
    let priceText: String
    let progress: Double
    let isTimer: Bool
    let statusText: String
}

struct HomeNoticeViewModel: Equatable {
    let title: String
    let lines: [String]
    let completesGoal: Bool
}

struct HomeViewModel {
    let daysLeft: Int
    let nextPaydayText: String
    let paydaySubtitle: String
    let hasReview: Bool
    let cards: [HomeCardViewModel]
    let emptyText: String?
    let notice: HomeNoticeViewModel?
}

struct HomeSnapshot {
    let cooling: [Want]
    let reviewQueue: [Want]
    let payday: PaydaySchedule
    let settings: PaydaySettings
    var monthEnd: MonthEndSummary?
}

protocol HomeViewProtocol: AnyObject {
    func render(_ model: HomeViewModel)
}

protocol HomePresenterProtocol: AnyObject {
    func viewWillAppear()
    func tapAdd()
    func tapPayday()
    func tapWant(id: UUID)
    func tapNotice()
    func dismissNotice()
}

protocol HomeInteractorProtocol: AnyObject {
    var output: HomeInteractorOutput? { get set }
    func snapshot() -> HomeSnapshot
    func dismissMonthEndSummary()
}

protocol HomeInteractorOutput: AnyObject {
    func dataDidChange()
}

protocol HomeRouterProtocol: AnyObject {
    func showAddWant()
    func showPaydayPreview()
    func showItemDetail(id: UUID)
    /// Opens Saved, then the goal-complete moment when `completedGoalId` is set.
    func showSaved(completedGoalId: UUID?)
}
