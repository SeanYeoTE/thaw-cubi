import Foundation

final class SavedPresenter: SavedPresenterProtocol {
    private weak var view: SavedViewProtocol?
    private let interactor: SavedInteractorProtocol
    private let router: SavedRouterProtocol
    private let goal = Decimal(2000)

    init(view: SavedViewProtocol, interactor: SavedInteractorProtocol, router: SavedRouterProtocol) {
        self.view = view
        self.interactor = interactor
        self.router = router
    }

    func viewWillAppear() {
        let wants = interactor.wants
        let skipped = wants.filter { $0.status == .skipped }
        let decided = wants.filter { $0.status != .cooling }
        let kept = skipped.reduce(Decimal(0)) { $0 + $1.price }
        let fraction = NSDecimalNumber(decimal: kept / goal).doubleValue
        let pattern = decided.isEmpty
            ? "Decide on a few wants at payday and your pattern will show up here."
            : "By payday, you've let go of \(skipped.count) in \(decided.count) wants."
        view?.render(SavedViewModel(
            keptText: Formatting.sgd(kept),
            goalTitle: "Goal: Japan trip",
            goalFraction: fraction,
            goalCaption: "\(Formatting.sgd(kept)) of \(Formatting.sgd(goal))",
            skippedText: "\(skipped.count) of \(decided.count)",
            pattern: pattern,
            skippedLines: skipped.map { "\($0.name) · \(Formatting.sgd($0.price))" }
        ))
    }
}
