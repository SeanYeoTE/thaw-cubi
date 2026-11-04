import Foundation

final class GoalCompleteInteractor: GoalCompleteInteractorProtocol {
    private let store: WantStore
    private let goalId: UUID

    init(store: WantStore, goalId: UUID) {
        self.store = store
        self.goalId = goalId
    }

    var goal: Goal? { store.goal(id: goalId) }

    var overflow: [GoalOverflow] {
        guard let summary = store.monthEndSummary,
              summary.applied.contains(where: { $0.goalId == goalId }) else { return [] }
        return summary.applied.filter { $0.goalId != goalId && $0.amount > 0 }
            .map { GoalOverflow(goalName: $0.goalName, amount: $0.amount) }
    }

    func archive() { store.archiveGoal(id: goalId) }
}
