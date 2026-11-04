import Foundation

struct SavedGoalRowViewModel {
    let id: UUID
    let card: GoalCardModel
}

struct SavedPoolViewModel: Equatable {
    let amountText: String
    let detail: String
}

struct SavedViewModel {
    let keptText: String
    let skippedText: String
    let pattern: String
    let skippedLines: [String]
    let pool: SavedPoolViewModel?
    let goals: [SavedGoalRowViewModel]
    let finishedTitle: String?
    let finishedExpanded: Bool
    let finished: [SavedGoalRowViewModel]
    /// Shown when there are no goals and the invite has not been hidden.
    let showsInvite: Bool
}

protocol SavedViewProtocol: AnyObject {
    func render(_ model: SavedViewModel)
}

protocol SavedPresenterProtocol: AnyObject {
    func viewWillAppear()
    func tapGoal(id: UUID)
    func tapAddGoal()
    func tapNotNow()
    func tapFinishedHeader()
}

protocol SavedInteractorProtocol: AnyObject {
    var output: SavedInteractorOutput? { get set }
    var wants: [Want] { get }
    var activeGoals: [Goal] { get }
    var finishedGoals: [Goal] { get }
    var inviteHiddenUntil: Date? { get }
    func pendingPool(now: Date) -> PendingPool
    func hideInvite(until: Date)
}

protocol SavedInteractorOutput: AnyObject {
    func dataDidChange()
}

protocol SavedRouterProtocol: AnyObject {
    func showGoalDetail(id: UUID)
    func showGoalEditor()
}
