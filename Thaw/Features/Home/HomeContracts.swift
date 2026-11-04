import Foundation

struct HomeCardViewModel: Equatable {
    let id: UUID
    let name: String
    let priceText: String
    let progress: Double
    let isTimer: Bool
    let statusText: String
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

protocol HomeViewProtocol: AnyObject {
    func render(_ model: HomeViewModel)
}

protocol HomePresenterProtocol: AnyObject {
    func viewWillAppear()
    func tapAdd()
    func tapPayday()
    func tapWant(id: UUID)
}

protocol HomeInteractorProtocol: AnyObject {
    var output: HomeInteractorOutput? { get set }
    func snapshot() -> HomeSnapshot
}

protocol HomeInteractorOutput: AnyObject {
    func dataDidChange()
}

protocol HomeRouterProtocol: AnyObject {
    func showAddWant()
    func showPaydayPreview()
    func showItemDetail(id: UUID)
}
