import Foundation

final class SavedPresenter: SavedPresenterProtocol {
    private weak var view: SavedViewProtocol?
    private let interactor: SavedInteractorProtocol
    private let router: SavedRouterProtocol

    // Explicit deinit: the synthesized one on a MainActor class with weak refs corrupts the heap in the test host.
    deinit {}

    init(view: SavedViewProtocol, interactor: SavedInteractorProtocol, router: SavedRouterProtocol) {
        self.view = view
        self.interactor = interactor
        self.router = router
    }

    func viewWillAppear() {
        let wants = interactor.wants
        let decided = wants.filter { $0.status != .cooling }
        let stats = ProgressStats.make(wants: wants, funMoney: interactor.funMoney)
        let history = decided.sorted { $0.frozenOn > $1.frozenOn }.map { want in
            SavedHistoryRow(
                name: want.name,
                priceText: Formatting.sgd(want.price),
                outcome: want.status == .skipped ? "Skipped" : "Bought",
                dateText: "Frozen " + want.frozenOn.formatted(.dateTime.day().month(.abbreviated).year()),
                isSkipped: want.status == .skipped
            )
        }
        view?.render(SavedViewModel(
            savedText: Formatting.sgd(stats.saved),
            progress: decided.isEmpty ? nil : progress(for: stats),
            emptyText: decided.isEmpty ? "Decide on a few wants at payday and your progress will show up here." : nil,
            history: history
        ))
    }

    private func progress(for stats: ProgressStats) -> SavedProgressViewModel {
        let streak = SavedProgressViewModel.Stat(
            value: stats.streak == 0 ? "No streak yet" : stats.streak == 1 ? "1 payday in a row" : "\(stats.streak) paydays in a row",
            caption: stats.streak == 0 ? "Skip one want at payday to start a streak." : "You let a want go at each one."
        )
        let comparison = SavedProgressViewModel.Stat(
            value: stats.funMoneyMonths >= 1
                ? String(format: "%.1f months of fun money", stats.funMoneyMonths)
                : "\(Int((stats.funMoneyMonths * 100).rounded()))% of a month's fun money",
            caption: "That's what you chose not to spend."
        )
        let winRate = SavedProgressViewModel.Stat(
            value: "\(stats.winRatePercent)% let go",
            caption: "You skipped \(stats.skippedCount) of \(stats.decidedCount) wants you froze."
        )
        return SavedProgressViewModel(stats: [streak, comparison, winRate])
    }
}
