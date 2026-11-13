import Foundation

final class StillWantItPresenter: StillWantItPresenterProtocol {
    private weak var view: StillWantItViewProtocol?
    private let interactor: StillWantItInteractorProtocol
    private let router: StillWantItRouterProtocol
    private let onFinish: (() -> Void)?
    private var index = 0
    /// Wants bought in this session only; earlier buys this payday aren't netted from fun money.
    private var bought: [Want] = []
    /// True while a decision is applied (the Let go moment) or the screen is leaving.
    private var isBusy = false

    // Explicit deinit: the synthesized one on a MainActor class with weak refs corrupts the heap in the test host.
    deinit {}

    init(view: StillWantItViewProtocol, interactor: StillWantItInteractorProtocol,
         router: StillWantItRouterProtocol, onFinish: (() -> Void)?) {
        self.view = view
        self.interactor = interactor
        self.router = router
        self.onFinish = onFinish
    }

    private var isFinished: Bool { index >= interactor.wants.count }

    /// The want on screen; nil once every want is decided.
    private var current: Want? {
        interactor.wants.indices.contains(index) ? interactor.wants[index] : nil
    }

    func viewDidLoad() {
        guard !interactor.wants.isEmpty else { return }
        render()
    }

    func tapLetGo() {
        guard let want = beginDecision() else { return }
        interactor.skip(want)
        // Publish straight away so other tabs update during the moment, not after it.
        interactor.publishChange()
        let line = CubiMood.proudLine(amount: Formatting.sgd(want.price))
        view?.showSkipMoment(line: line) { [weak self] in self?.advance() }
    }

    func tapBuy() {
        guard let want = beginDecision() else { return }
        interactor.buy(want)
        interactor.publishChange()
        bought.append(want)
        advance()
    }

    func tapWait() {
        guard let want = beginDecision() else { return }
        interactor.wait(want)
        interactor.publishChange()
        advance()
    }

    func tapClose() {
        guard !isFinished else { return }
        router.dismiss(completion: nil)
    }

    /// The want to decide, or nil when a decision is already running or every want is decided.
    private func beginDecision() -> Want? {
        guard !isBusy, let want = current else { return nil }
        isBusy = true
        view?.setActionsEnabled(false)
        return want
    }

    /// Navigation only: the decision is already written and published.
    private func advance() {
        index += 1
        if isFinished {
            router.dismiss(completion: onFinish)
        } else {
            render()
            isBusy = false
            view?.setActionsEnabled(true)
        }
    }

    private func render() {
        guard let want = current else { return }
        let budget = interactor.budget
        let reason = want.reason.isEmpty ? "No reason written." : "\u{201C}\(want.reason)\u{201D}"
        // Spoken-for if this want is bought too; quick thaws don't count against fun money (D4).
        let plan = FunMoneyPlan.make(wants: bought + [want], funMoney: budget,
                                     timerThreshold: interactor.timerThreshold)
        let summary = FunMoneySummary(kept: plan.paydayTotal, budget: plan.funMoney)
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
