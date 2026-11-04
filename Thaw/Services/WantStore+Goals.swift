import Foundation

nonisolated extension WantStore {
    var goals: [Goal] { goalState.goals }
    var activeGoals: [Goal] { GoalLedger.fillOrder(goalState.goals) }
    var finishedGoals: [Goal] {
        goalState.goals.filter { $0.status != .active }.sorted { ($0.completedOn ?? $0.createdOn) > ($1.completedOn ?? $1.createdOn) }
    }
    var monthEndSummary: MonthEndSummary? { goalState.summary }
    var goalInviteHiddenUntil: Date? { goalState.inviteHiddenUntil }

    func goal(id: UUID) -> Goal? { goalState.goals.first { $0.id == id } }

    @discardableResult
    func addGoal(name: String, target: Decimal, deadline: Date?, now: Date) throws -> Goal {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw GoalError.emptyName }
        guard GoalLedger.validate(target: target, funMoney: effectiveSettings.funMoney) else { throw GoalError.targetTooLow }
        let goal = Goal(name: trimmed, target: Self.rounded(target), deadline: deadline, createdOn: now)
        goalState.goals.append(goal)
        commitGoalChange()
        return goal
    }

    func updateGoal(id: UUID, name: String, target: Decimal, deadline: Date?) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw GoalError.emptyName }
        guard GoalLedger.validate(target: target, funMoney: effectiveSettings.funMoney) else { throw GoalError.targetTooLow }
        guard let index = goalState.goals.firstIndex(where: { $0.id == id }) else { return }
        goalState.goals[index].name = trimmed
        goalState.goals[index].target = Self.rounded(target)
        goalState.goals[index].deadline = deadline
        if goalState.goals[index].status == .active, goalState.goals[index].isFunded {
            goalState.goals[index].status = .completed
            goalState.goals[index].completedOn = .now
            goalState.goals[index].history.append(GoalEvent(date: .now, kind: .completed))
        }
        commitGoalChange()
    }

    func deleteGoal(id: UUID) {
        goalState.goals.removeAll { $0.id == id }
        commitGoalChange()
    }

    func archiveGoal(id: UUID) {
        guard let index = goalState.goals.firstIndex(where: { $0.id == id }) else { return }
        goalState.goals[index].status = .archived
        commitGoalChange()
    }

    func pendingPool(now: Date) -> PendingPool {
        let figures = poolFigures(inMonthOf: now)
        return PendingPool(skipped: figures.skipped, unspent: figures.unspent,
                           total: GoalLedger.pool(skipped: figures.skipped, unspent: figures.unspent))
    }

    /// Lands each fully elapsed month's pool on goals (once per month), then extends overdue goals.
    func runMonthEndIfNeeded(now: Date) -> MonthEndSummary? {
        guard !goalState.goals.isEmpty else { return nil }
        let currentMonth = monthStart(now)
        var goals = goalState.goals
        var month: Date?
        if let last = goalState.lastMonth {
            month = calendar.date(byAdding: .month, value: 1, to: last)
        } else if let earliest = goals.filter({ $0.status == .active }).map(\.createdOn).min() {
            month = monthStart(earliest)
        }

        var total: MonthEndSummary?
        var processed: Date?
        var guardCount = 0
        while let current = month, current < currentMonth, guardCount < 120 {
            guardCount += 1
            defer { month = calendar.date(byAdding: .month, value: 1, to: current) }
            processed = current
            guard let monthEnd = calendar.date(byAdding: .month, value: 1, to: current) else { break }
            let eligible = goals.filter { $0.status == .active && $0.createdOn < monthEnd }
            guard !eligible.isEmpty else { continue }
            let figures = poolFigures(inMonthOf: current)
            let pool = GoalLedger.pool(skipped: figures.skipped, unspent: figures.unspent)
            let result = GoalLedger.consolidate(pool: pool, goals: eligible, month: current)
            for updated in result.goals {
                if let index = goals.firstIndex(where: { $0.id == updated.id }) { goals[index] = updated }
            }
            let contributions = GoalLedger.fillOrder(eligible).compactMap { goal -> MonthEndSummary.GoalContribution? in
                guard let amount = result.applied[goal.id] else { return nil }
                return .init(goalId: goal.id, goalName: goal.name, amount: amount,
                             completed: result.completed.contains(goal.id))
            }
            if var summary = total {
                summary.month = current
                summary.pool += pool
                summary.skipped += figures.skipped
                summary.unspent += figures.unspent
                summary.keptRemainder += result.keptRemainder
                for item in contributions {
                    if let index = summary.applied.firstIndex(where: { $0.goalId == item.goalId }) {
                        summary.applied[index].amount += item.amount
                        summary.applied[index].completed = summary.applied[index].completed || item.completed
                    } else {
                        summary.applied.append(item)
                    }
                }
                total = summary
            } else {
                total = MonthEndSummary(month: current, pool: pool, skipped: figures.skipped,
                                        unspent: figures.unspent, applied: contributions,
                                        keptRemainder: result.keptRemainder)
            }
        }

        let extended = GoalLedger.extendOverdue(goals, now: now, settings: effectiveSettings)
        let changed = extended != goalState.goals || processed != nil
        goalState.goals = extended
        if let processed { goalState.lastMonth = processed }
        if let total { goalState.summary = total }
        if changed { commitGoalChange() }
        return total
    }

    func dismissMonthEndSummary() {
        goalState.summary = nil
        commitGoalChange()
    }

    func hideGoalInvite(until: Date) {
        goalState.inviteHiddenUntil = until
        commitGoalChange()
    }

    private func commitGoalChange() {
        persist()
        NotificationCenter.default.post(name: Notification.Name("thaw.dataChanged"), object: nil)
    }

    private func monthStart(_ date: Date) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    private func poolFigures(inMonthOf date: Date) -> (skipped: Decimal, unspent: Decimal) {
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return (0, 0) }
        let decided = wants.compactMap { want -> (Want, Date)? in
            guard let day = want.decidedOn, interval.contains(day) else { return nil }
            return (want, day)
        }
        let skipped = decided.filter { $0.0.status == .skipped }.reduce(Decimal(0)) { $0 + $1.0.price }
        let bought = decided.filter { $0.0.status == .bought }.reduce(Decimal(0)) { $0 + $1.0.price }
        return (skipped, max(0, effectiveSettings.funMoney - bought))
    }
}
