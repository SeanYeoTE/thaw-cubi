import Foundation

struct GoalContributionRow: Equatable {
    let month: String
    let amount: String
}

struct GoalHistoryRow: Equatable {
    let title: String
    let detail: String?
    let date: String
}

struct GoalDetailViewModel: Equatable {
    let name: String
    let savedText: String
    let progress: Double
    let progressText: String
    let dueText: String?
    let fillsFirst: Bool
    let extended: Bool
    let canEdit: Bool
    let canArchive: Bool
    let contributions: [GoalContributionRow]
    let history: [GoalHistoryRow]
    let deleteNote: String
    let accessibilityLabel: String
}

protocol GoalDetailViewProtocol: AnyObject {
    func render(_ model: GoalDetailViewModel)
    func showDeleteConfirmation(title: String, message: String)
}

protocol GoalDetailPresenterProtocol: AnyObject {
    func viewDidLoad()
    func tapEdit()
    func tapArchive()
    func tapDelete()
    func confirmDelete()
}

protocol GoalDetailInteractorProtocol: AnyObject {
    var goal: Goal? { get }
    /// The goal that currently fills first, nil when none is active.
    var firstFillingGoalId: UUID? { get }
    func archive()
    func delete()
}

protocol GoalDetailInteractorOutput: AnyObject {
    func dataDidChange()
}

protocol GoalDetailRouterProtocol: AnyObject {
    func showEditor()
    func pop()
}
