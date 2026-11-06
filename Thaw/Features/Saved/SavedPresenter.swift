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

    func tapEditDecision(id: UUID) {
        guard let want = decidedWant(id) else { return }
        let other: SavedDecisionChoice = want.status == .skipped
            ? SavedDecisionChoice(option: .markBought, title: "Mark as bought")
            : SavedDecisionChoice(option: .markSkipped, title: "Mark as skipped")
        view?.showDecisionOptions(id: id, sheet: SavedDecisionSheet(
            title: want.name,
            message: "You \(want.status == .skipped ? "skipped" : "bought") this. Change your decision?",
            choices: [SavedDecisionChoice(option: .moveBackToCooling, title: "Move back to cooling"), other],
            cancelTitle: "Cancel"
        ))
    }

    func chooseDecisionOption(id: UUID, option: SavedDecisionOption) {
        guard let want = decidedWant(id) else { return }
        switch option {
        case .moveBackToCooling:
            interactor.reopen(id)
        case .markBought where want.status == .skipped:
            interactor.setDecision(id, to: .bought)
        case .markSkipped where want.status == .bought:
            interactor.setDecision(id, to: .skipped)
        case .markBought, .markSkipped:
            break
        }
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
                dateText: "Frozen " + want.frozenOn.formatted(.dateTime.day().month(.abbreviated).year()),
                isSkipped: want.status == .skipped
            )
        }
        view?.render(SavedViewModel(
            cubi: cubi(decided: decided.count, stats: stats),
            savedText: Formatting.sgd(stats.saved),
            progress: decided.isEmpty ? nil : progress(for: stats),
            emptyText: decided.isEmpty ? "Decide on a few wants at payday and your progress will show up here." : nil,
            history: history
        ))
    }

    // Mood is a pure function of the stats, so Cubi only changes when the numbers do.
    private func cubi(decided: Int, stats: ProgressStats) -> SavedCubiViewModel {
        if decided == 0 {
            return SavedCubiViewModel(mood: .frozen, line: "Brr. Decide on a few wants at payday and I'll keep score.")
        }
        if stats.streak >= 1 {
            return SavedCubiViewModel(mood: .proud, line: CubiMood.proudLine(amount: Formatting.sgd(stats.saved)))
        }
        return SavedCubiViewModel(mood: .snoozing, line: "A fresh start. Let one go at payday and I'll cheer.")
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
