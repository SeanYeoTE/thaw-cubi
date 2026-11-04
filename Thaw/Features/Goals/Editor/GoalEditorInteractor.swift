import Foundation

final class GoalEditorInteractor: GoalEditorInteractorProtocol {
    private let store: WantStore
    private let goalId: UUID?

    init(store: WantStore, goalId: UUID?) {
        self.store = store
        self.goalId = goalId
    }

    var goal: Goal? { goalId.flatMap { store.goal(id: $0) } }
    var funMoney: Decimal { store.effectiveSettings.funMoney }
    var now: Date { .now }
    var suggestedDeadline: Date { store.effectiveSettings.nextPayday(after: now, calendar: .current) }

    func save(name: String, target: Decimal, deadline: Date?) throws {
        if let goalId {
            try store.updateGoal(id: goalId, name: name, target: target, deadline: deadline)
        } else {
            _ = try store.addGoal(name: name, target: target, deadline: deadline, now: now)
        }
    }
}
