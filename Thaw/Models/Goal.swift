import Foundation

nonisolated struct GoalEvent: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable { case contribution, extended, completed }
    var date: Date
    var kind: Kind
    var amount: Decimal?
    var newDeadline: Date?

    init(date: Date, kind: Kind, amount: Decimal? = nil, newDeadline: Date? = nil) {
        self.date = date
        self.kind = kind
        self.amount = amount
        self.newDeadline = newDeadline
    }
}

nonisolated struct Goal: Identifiable, Codable, Equatable, Sendable {
    enum Status: String, Codable, Sendable { case active, completed, archived }

    let id: UUID
    var name: String
    var target: Decimal
    var saved: Decimal
    var deadline: Date?
    let createdOn: Date
    var status: Status
    var completedOn: Date?
    var history: [GoalEvent]

    init(id: UUID = UUID(), name: String, target: Decimal, saved: Decimal = 0, deadline: Date? = nil,
         createdOn: Date, status: Status = .active, completedOn: Date? = nil, history: [GoalEvent] = []) {
        self.id = id
        self.name = name
        self.target = target
        self.saved = saved
        self.deadline = deadline
        self.createdOn = createdOn
        self.status = status
        self.completedOn = completedOn
        self.history = history
    }

    var isFunded: Bool { saved >= target }

    var progress: Double {
        guard target > 0 else { return 0 }
        return min(1, max(0, NSDecimalNumber(decimal: saved / target).doubleValue))
    }

    var isExtended: Bool { history.contains { $0.kind == .extended } }
}

nonisolated enum GoalError: Error, Equatable, Sendable {
    case targetTooLow
    case emptyName
}

nonisolated struct PendingPool: Equatable, Sendable {
    var skipped: Decimal
    var unspent: Decimal
    var total: Decimal
}

nonisolated struct MonthEndSummary: Codable, Equatable, Sendable {
    var month: Date
    var pool: Decimal
    var skipped: Decimal
    var unspent: Decimal
    var applied: [GoalContribution]
    var keptRemainder: Decimal

    struct GoalContribution: Codable, Equatable, Sendable {
        var goalId: UUID
        var goalName: String
        var amount: Decimal
        var completed: Bool
    }
}

nonisolated struct GoalState: Sendable {
    var goals: [Goal] = []
    var lastMonth: Date?
    var summary: MonthEndSummary?
    var inviteHiddenUntil: Date?
}

nonisolated enum GoalLedger {
    static func fillOrder(_ goals: [Goal]) -> [Goal] {
        goals.filter { $0.status == .active }.sorted { a, b in
            switch (a.deadline, b.deadline) {
            case let (x?, y?): return x != y ? x < y : a.createdOn < b.createdOn
            case (nil, nil): return a.createdOn < b.createdOn
            case (_?, nil): return true
            case (nil, _?): return false
            }
        }
    }

    static func pool(skipped: Decimal, unspent: Decimal) -> Decimal {
        max(0, skipped) + max(0, unspent)
    }

    struct Result: Equatable, Sendable {
        var goals: [Goal]
        var applied: [UUID: Decimal]
        var keptRemainder: Decimal
        var completed: [UUID]
    }

    static func consolidate(pool: Decimal, goals: [Goal], month: Date) -> Result {
        var updated = goals
        var remaining = max(0, pool)
        var applied: [UUID: Decimal] = [:]
        var completed: [UUID] = []
        for goal in fillOrder(goals) where remaining > 0 {
            guard let index = updated.firstIndex(where: { $0.id == goal.id }) else { continue }
            let room = max(0, goal.target - goal.saved)
            let amount = min(room, remaining)
            guard amount > 0 else { continue }
            updated[index].saved += amount
            updated[index].history.append(GoalEvent(date: month, kind: .contribution, amount: amount))
            applied[goal.id] = amount
            remaining -= amount
            if updated[index].isFunded {
                updated[index].status = .completed
                updated[index].completedOn = month
                updated[index].history.append(GoalEvent(date: month, kind: .completed))
                completed.append(goal.id)
            }
        }
        return Result(goals: updated, applied: applied, keptRemainder: remaining, completed: completed)
    }

    static func extendOverdue(_ goals: [Goal], now: Date, settings: PaydaySettings) -> [Goal] {
        let calendar = Calendar.current
        return goals.map { goal in
            var goal = goal
            guard goal.status == .active, !goal.isFunded, var deadline = goal.deadline else { return goal }
            var guardCount = 0
            while deadline < now, guardCount < 120 {
                let next = settings.nextPayday(after: deadline, calendar: calendar)
                guard next > deadline else { break }
                deadline = next
                goal.history.append(GoalEvent(date: now, kind: .extended, newDeadline: next))
                guardCount += 1
            }
            goal.deadline = deadline
            return goal
        }
    }

    static func validate(target: Decimal, funMoney: Decimal) -> Bool { target > funMoney }
}
