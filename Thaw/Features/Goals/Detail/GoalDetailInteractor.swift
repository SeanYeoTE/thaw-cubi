import Foundation

final class GoalDetailInteractor: GoalDetailInteractorProtocol {
    private let store: WantStore
    private let goalId: UUID
    private var observer: DataChangeObserver?
    weak var output: GoalDetailInteractorOutput? {
        didSet {
            observer?.stop()
            observer = DataChangeObserver { [weak self] in self?.output?.dataDidChange() }
        }
    }

    // Explicit deinit: the synthesized one on a MainActor class with weak refs corrupts the heap in the test host.
    deinit {}

    init(store: WantStore, goalId: UUID) {
        self.store = store
        self.goalId = goalId
    }

    var goal: Goal? { store.goal(id: goalId) }
    var firstFillingGoalId: UUID? { store.activeGoals.first?.id }

    func archive() { store.archiveGoal(id: goalId) }
    func delete() { store.deleteGoal(id: goalId) }
}
