import Foundation

final class SavedPresenter: SavedPresenterProtocol, SavedInteractorOutput {
    static let inviteHiddenDays = 30

    private weak var view: SavedViewProtocol?
    private let interactor: SavedInteractorProtocol
    private let router: SavedRouterProtocol
    private let now: () -> Date
    private var finishedExpanded = false

    // Explicit deinit: the synthesized one on a MainActor class with weak refs corrupts the heap in the test host.
    deinit {}

    init(view: SavedViewProtocol, interactor: SavedInteractorProtocol, router: SavedRouterProtocol,
         now: @escaping () -> Date = { Date() }) {
        self.view = view
        self.interactor = interactor
        self.router = router
        self.now = now
        interactor.output = self
    }

    func viewWillAppear() { refresh() }

    func dataDidChange() { refresh() }

    func tapGoal(id: UUID) { router.showGoalDetail(id: id) }

    func tapAddGoal() { router.showGoalEditor() }

    func tapNotNow() {
        let date = now()
        let until = Calendar.current.date(byAdding: .day, value: Self.inviteHiddenDays, to: date) ?? date
        interactor.hideInvite(until: until)
        refresh()
    }

    func tapFinishedHeader() {
        finishedExpanded.toggle()
        refresh()
    }

    private func refresh() {
        let date = now()
        let wants = interactor.wants
        let skipped = wants.filter { $0.status == .skipped }
        let decided = wants.filter { $0.status != .cooling }
        let kept = skipped.reduce(Decimal(0)) { $0 + $1.price }
        let pattern = decided.isEmpty
            ? "Decide on a few wants at payday and your pattern will show up here."
            : "By payday, you've let go of \(skipped.count) in \(decided.count) wants."

        let active = interactor.activeGoals
        let finished = interactor.finishedGoals
        var pool: SavedPoolViewModel?
        if !active.isEmpty {
            let figures = interactor.pendingPool(now: date)
            pool = SavedPoolViewModel(
                amountText: Formatting.sgd(figures.total),
                detail: "\(Formatting.sgd(figures.skipped)) skipped + \(Formatting.sgd(figures.unspent)) unspent so far. "
                    + "Lands in goals at month end."
            )
        }
        let hiddenUntil = interactor.inviteHiddenUntil
        let inviteHidden = hiddenUntil.map { $0 > date } ?? false
        let hasGoals = !active.isEmpty || !finished.isEmpty

        view?.render(SavedViewModel(
            keptText: Formatting.sgd(kept),
            skippedText: "\(skipped.count) of \(decided.count)",
            pattern: pattern,
            skippedLines: skipped.map { "\($0.name) · \(Formatting.sgd($0.price))" },
            pool: pool,
            goals: active.enumerated().map { row(for: $1, fillsFirst: $0 == 0) },
            finishedTitle: finished.isEmpty ? nil : "Finished goals (\(finished.count))",
            finishedExpanded: finishedExpanded,
            finished: finishedExpanded ? finished.map { row(for: $0, fillsFirst: false) } : [],
            showsInvite: !hasGoals && !inviteHidden
        ))
    }

    private func row(for goal: Goal, fillsFirst: Bool) -> SavedGoalRowViewModel {
        let saved = Formatting.sgd(goal.saved)
        let target = Formatting.sgd(goal.target)
        let deadline = goal.deadline.map { "Due \(Self.deadlineText($0))" }
        let percent = Int((goal.progress * 100).rounded())
        var label = "\(goal.name), \(saved) of \(target), \(percent) percent"
        if let deadline { label += ", \(deadline.lowercased())" }
        if fillsFirst { label += ", fills first" }
        if goal.isExtended { label += ", deadline extended" }
        return SavedGoalRowViewModel(id: goal.id, card: GoalCardModel(
            name: goal.name, savedText: saved, targetText: target, progress: goal.progress,
            deadlineText: deadline, fillsFirst: fillsFirst, extended: goal.isExtended, accessibilityLabel: label
        ))
    }

    private static func deadlineText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_SG")
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
}
