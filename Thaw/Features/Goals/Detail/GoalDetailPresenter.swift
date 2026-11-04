import Foundation

final class GoalDetailPresenter: GoalDetailPresenterProtocol, GoalDetailInteractorOutput {
    private weak var view: GoalDetailViewProtocol?
    private let interactor: GoalDetailInteractorProtocol
    private let router: GoalDetailRouterProtocol
    private let calendar: Calendar
    private let now: () -> Date
    private var leaving = false

    // Explicit deinit: the synthesized one on a MainActor class with weak refs corrupts the heap in the test host.
    deinit {}

    init(view: GoalDetailViewProtocol, interactor: GoalDetailInteractorProtocol, router: GoalDetailRouterProtocol,
         calendar: Calendar = .current, now: @escaping () -> Date = { .now }) {
        self.view = view
        self.interactor = interactor
        self.router = router
        self.calendar = calendar
        self.now = now
    }

    func viewDidLoad() { refresh() }

    func dataDidChange() { refresh() }

    func tapEdit() { router.showEditor() }

    func tapArchive() {
        leaving = true
        interactor.archive()
        router.pop()
    }

    func tapDelete() {
        guard let goal = interactor.goal else { return }
        view?.showDeleteConfirmation(title: "Delete \(goal.name)?", message: Self.deleteNote)
    }

    func confirmDelete() {
        leaving = true
        interactor.delete()
        router.pop()
    }

    private static let deleteNote = "Deleting removes the goal and its history. Money already saved stays in Kept."

    private func refresh() {
        guard !leaving else { return }
        guard let goal = interactor.goal else {
            leaving = true
            return router.pop()
        }
        view?.render(makeModel(goal))
    }

    private func makeModel(_ goal: Goal) -> GoalDetailViewModel {
        let isActive = goal.status == .active
        let fillsFirst = isActive && interactor.firstFillingGoalId == goal.id
        let percent = Int((goal.progress * 100).rounded(.down))
        let remaining = max(goal.target - goal.saved, 0)
        var due: String?
        if let deadline = goal.deadline {
            due = "Due \(Self.weekday(deadline))" + (isActive && remaining > 0 ? " · \(Formatting.sgd(remaining)) to go" : "")
        }
        var spoken = [goal.name, "\(Formatting.sgd(goal.saved)) of \(Formatting.sgd(goal.target))", "\(percent) percent"]
        if let due { spoken.append(due.prefix(1).lowercased() + due.dropFirst()) }
        if goal.isExtended { spoken.append("extended") }
        if fillsFirst { spoken.append("fills first") }
        return GoalDetailViewModel(
            name: goal.name,
            savedText: Formatting.sgd(goal.saved),
            progress: goal.progress,
            progressText: "of \(Formatting.sgd(goal.target)) · \(percent)%",
            dueText: due,
            fillsFirst: fillsFirst,
            extended: goal.isExtended,
            canEdit: isActive,
            canArchive: goal.status != .archived,
            contributions: contributions(goal),
            history: history(goal),
            deleteNote: Self.deleteNote,
            accessibilityLabel: spoken.joined(separator: ", "))
    }

    private func contributions(_ goal: Goal) -> [GoalContributionRow] {
        let events = goal.history.filter { $0.kind == .contribution && ($0.amount ?? 0) > 0 }
        let grouped = Dictionary(grouping: events) { calendar.dateInterval(of: .month, for: $0.date)?.start ?? $0.date }
        return grouped.keys.sorted(by: >).map { month in
            let total = grouped[month, default: []].reduce(Decimal(0)) { $0 + ($1.amount ?? 0) }
            return GoalContributionRow(month: monthTitle(month), amount: "+" + Formatting.sgd(total))
        }
    }

    private func history(_ goal: Goal) -> [GoalHistoryRow] {
        var rows: [(Date, GoalHistoryRow)] = []
        for event in goal.history {
            switch event.kind {
            case .contribution:
                continue
            case .extended:
                let detail = event.newDeadline.map { "Moved to \(Self.weekday($0)) (one payday)" }
                rows.append((event.date, GoalHistoryRow(title: "Deadline extended", detail: detail, date: Self.short(event.date))))
            case .completed:
                rows.append((event.date, GoalHistoryRow(title: "Goal completed", detail: nil, date: Self.short(event.date))))
            }
        }
        rows.append((goal.createdOn, GoalHistoryRow(title: "Goal created", detail: nil, date: Self.short(goal.createdOn))))
        return rows.sorted { $0.0 > $1.0 }.map(\.1)
    }

    private func monthTitle(_ date: Date) -> String {
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now())
        return Self.format(date, sameYear ? "MMMM" : "MMMM yyyy", calendar)
    }

    private static func weekday(_ date: Date) -> String { format(date, "EEE, d MMMM", .current) }
    private static func short(_ date: Date) -> String { format(date, "d MMM", .current) }

    private static func format(_ date: Date, _ pattern: String, _ calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_SG")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
