import Foundation

final class StillWantItPresenter: StillWantItPresenterProtocol {
    private weak var view: StillWantItViewProtocol?
    private let interactor: StillWantItInteractorProtocol
    private let router: StillWantItRouterProtocol
    private let onFinish: (() -> Void)?
    private var index = 0
    private var boughtTotal: Decimal = 0

    // Explicit deinit: the synthesized one on a MainActor class with weak refs corrupts the heap in the test host.
    deinit {}

    init(view: StillWantItViewProtocol, interactor: StillWantItInteractorProtocol,
         router: StillWantItRouterProtocol, onFinish: (() -> Void)?) {
        self.view = view
        self.interactor = interactor
        self.router = router
        self.onFinish = onFinish
    }

    private var current: Want { interactor.wants[index] }

    func viewDidLoad() {
        guard !interactor.wants.isEmpty else { return }
        render()
    }

    func tapLetGo() {
        let want = current
        interactor.skip(want)
        let line = CubiMood.proudLine(amount: Formatting.sgd(want.price))
        view?.showSkipMoment(line: line) { [weak self] in self?.advance() }
    }

    func tapBuy() {
        let want = current
        interactor.buy(want)
        boughtTotal += want.price
        advance()
    }

    func tapWait() {
        interactor.wait(current)
        advance()
    }

    func tapClose() {
        router.dismiss(completion: nil)
    }

    private func advance() {
        index += 1
        interactor.publishChange()
        if index >= interactor.wants.count {
            router.dismiss(completion: onFinish)
        } else {
            render()
        }
    }

    private func render() {
        let want = current
        let budget = interactor.budget
        let reason = want.reason.isEmpty ? "No reason written." : "\u{201C}\(want.reason)\u{201D}"
        let summary = FunMoneySummary.make(keptPrices: [boughtTotal, want.price], budget: budget)
        let count = interactor.wants.count
        view?.render(StillWantItViewModel(
            progressText: count > 1 ? "\(index + 1) of \(count)" : "",
            name: want.name,
            priceText: Formatting.sgd(want.price),
            quote: reason,
            dateText: Self.dateText(want.frozenOn),
            budgetCaption: "Fun money",
            budgetText: Formatting.sgd(budget),
            meterFraction: summary.fraction,
            meterIsOver: summary.overBy > 0,
            meterText: summary.overBy > 0
                ? "\(Formatting.sgd(summary.overBy)) over if you buy"
                : "\(Formatting.sgd(summary.remaining)) left if you buy",
            letGoTitle: "Let go \u{00B7} save \(Formatting.sgd(want.price))",
            buyTitle: "Buy it",
            waitTitle: "Wait a payday"
        ))
    }

    private static func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_SG")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
}
