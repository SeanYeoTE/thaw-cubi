import Foundation

final class SavedPresenter: SavedPresenterProtocol, SavedInteractorOutput {
    private weak var view: SavedViewProtocol?
    private let interactor: SavedInteractorProtocol
    private let router: SavedRouterProtocol

    // Explicit deinit: the synthesized one on a MainActor class with weak refs corrupts the heap in the test host.
    deinit {}

    init(view: SavedViewProtocol, interactor: SavedInteractorProtocol, router: SavedRouterProtocol) {
        self.view = view
        self.interactor = interactor
        self.router = router
        interactor.output = self
    }

    func viewWillAppear() { refresh() }

    func dataDidChange() { refresh() }

    func tapEdit(id: UUID) {
        guard decidedWant(id) != nil else { return }
        router.showEdit(id: id)
    }

    func tapDelete(id: UUID) {
        guard let want = decidedWant(id) else { return }
        view?.showDeleteConfirmation(id: id, confirmation: SavedDeleteConfirmation(
            title: "Delete \(want.name)?",
            message: "It will be removed from Thaw, including your history and savings total.",
            deleteTitle: "Delete",
            cancelTitle: "Cancel"
        ))
    }

    func confirmDelete(id: UUID) {
        guard interactor.wants.contains(where: { $0.id == id }) else { return }
        interactor.delete(id)
    }

    private func decidedWant(_ id: UUID) -> Want? {
        interactor.wants.first { $0.id == id && $0.status != .cooling }
    }

    private func refresh() {
        let wants = interactor.wants
        let decided = wants.filter { $0.status != .cooling }
        let stats = ProgressStats.make(wants: wants, funMoney: interactor.funMoney)
        let history = decided.sorted { $0.frozenOn > $1.frozenOn }.map { want in
            SavedHistoryRow(
                id: want.id,
                name: want.name,
                priceText: Formatting.sgd(want.price),
                outcome: want.status == .skipped ? "Skipped" : "Bought",
                dateText: want.frozenOn.formatted(.dateTime.day().month(.abbreviated).year()),
                isSkipped: want.status == .skipped
            )
        }
        view?.render(SavedViewModel(
            cubi: cubi(decided: decided.count, stats: stats),
            savedText: Formatting.sgd(stats.saved),
            monthlySaved: monthlySaved(decided),
            progress: decided.isEmpty ? nil : progress(for: stats),
            emptyText: decided.isEmpty ? "Decide on a few wants at payday and your progress will show up here." : nil,
            history: history
        ))
    }

    /// Skipped prices grouped by the month they were frozen, oldest first.
    private func monthlySaved(_ decided: [Want]) -> [SavedMonthlyAmount] {
        let calendar = Calendar.current
        let skipped = decided.filter { $0.status == .skipped }
        let byMonth = Dictionary(grouping: skipped) {
            calendar.date(from: calendar.dateComponents([.year, .month], from: $0.frozenOn)) ?? $0.frozenOn
        }
        return byMonth
            .map { SavedMonthlyAmount(month: $0.key, amount: $0.value.reduce(0) { $0 + NSDecimalNumber(decimal: $1.price).doubleValue }) }
            .sorted { $0.month < $1.month }
    }

    // Mood is a pure function of the stats, so Cubi only changes when the numbers do.
    private func cubi(decided: Int, stats: ProgressStats) -> SavedCubiViewModel {
        if decided == 0 {
            return SavedCubiViewModel(mood: .frozen, line: "Brr. Decide on a few wants at payday and I'll keep score.")
        }
        if stats.streak >= 1 {
            return SavedCubiViewModel(mood: .proud, line: CubiMood.proud.line)
        }
        return SavedCubiViewModel(mood: .snoozing, line: "A fresh start. Let one go at payday and I'll cheer.")
    }

    private func progress(for stats: ProgressStats) -> SavedProgressViewModel {
        let streak = SavedProgressViewModel.Stat(
            value: "\(stats.streak)",
            caption: stats.streak == 1 ? "payday streak" : "paydays in a row",
            spoken: stats.streak == 0
                ? "No streak yet. Skip one want at payday to start a streak."
                : "\(stats.streak) \(stats.streak == 1 ? "payday" : "paydays") in a row. You let a want go at each one."
        )
        let months = stats.funMoneyMonths
        let comparisonValue = months >= 1 ? String(format: "%.1f", months) : "\(Int((months * 100).rounded()))%"
        let comparison = SavedProgressViewModel.Stat(
            value: comparisonValue,
            caption: months >= 1 ? "months of fun money" : "of a month's fun money",
            spoken: "\(comparisonValue) \(months >= 1 ? "months of fun money" : "of a month's fun money"). That's what you chose not to spend."
        )
        let winRate = SavedProgressViewModel.Stat(
            value: "\(stats.winRatePercent)%",
            caption: "let go · \(stats.skippedCount) of \(stats.decidedCount)",
            spoken: "\(stats.winRatePercent) percent let go. You skipped \(stats.skippedCount) of \(stats.decidedCount) wants you froze."
        )
        return SavedProgressViewModel(stats: [streak, comparison, winRate])
    }
}
