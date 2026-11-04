import Foundation

struct GoalCompleteViewModel: Equatable {
    let title: String
    let headline: String
    let amountText: String
    let body: String
    let footnote: String
}

protocol GoalCompleteViewProtocol: AnyObject {
    func render(_ model: GoalCompleteViewModel)
    func playSuccessFeedback()
}

protocol GoalCompletePresenterProtocol: AnyObject {
    func viewDidLoad()
    func tapArchive()
    func tapLater()
}

/// Money from the same month-end pool that flowed on to another goal.
struct GoalOverflow: Equatable {
    let goalName: String
    let amount: Decimal
}

protocol GoalCompleteInteractorProtocol: AnyObject {
    var goal: Goal? { get }
    var overflow: [GoalOverflow] { get }
    func archive()
}

protocol GoalCompleteRouterProtocol: AnyObject {
    /// Dismisses the screen, then reports completion.
    func finish()
}
