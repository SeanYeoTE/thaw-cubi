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
        let skipped = wants.filter { $0.status == .skipped }
        let decided = wants.filter { $0.status != .cooling }
        let saved = skipped.reduce(Decimal(0)) { $0 + $1.price }
        let pattern = decided.isEmpty
            ? "Decide on a few wants at payday and your pattern will show up here."
            : "By payday, you've let go of \(skipped.count) in \(decided.count) wants."
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
            savedText: Formatting.sgd(saved),
            skippedText: "\(skipped.count) of \(decided.count)",
            pattern: pattern,
            history: history
        ))
    }
}
