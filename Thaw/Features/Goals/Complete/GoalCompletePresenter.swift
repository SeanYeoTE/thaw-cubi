import Foundation

final class GoalCompletePresenter: GoalCompletePresenterProtocol {
    private weak var view: GoalCompleteViewProtocol?
    private let interactor: GoalCompleteInteractorProtocol
    private let router: GoalCompleteRouterProtocol

    // Explicit deinit: the synthesized one on a MainActor class with weak refs corrupts the heap in the test host.
    deinit {}

    init(view: GoalCompleteViewProtocol, interactor: GoalCompleteInteractorProtocol, router: GoalCompleteRouterProtocol) {
        self.view = view
        self.interactor = interactor
        self.router = router
    }

    func viewDidLoad() {
        guard let goal = interactor.goal else { return router.finish() }
        var body = "Your skipped wants and unspent fun money got you here."
        if let next = interactor.overflow.first {
            body += " The extra \(Formatting.sgd(next.amount)) went to \(next.goalName)."
        }
        body += " Enjoy it."
        view?.render(GoalCompleteViewModel(
            title: "Goal complete",
            headline: "\(goal.name) is fully funded",
            amountText: "\(Formatting.sgd(goal.target)) of \(Formatting.sgd(goal.target))",
            body: body,
            footnote: "Archived goals keep their history in Saved › Archived."))
        view?.playSuccessFeedback()
    }

    func tapArchive() {
        interactor.archive()
        router.finish()
    }

    func tapLater() { router.finish() }
}
