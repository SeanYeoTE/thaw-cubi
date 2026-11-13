import Foundation

final class PaydayReviewPresenter: PaydayReviewPresenterProtocol {
    private weak var view: PaydayReviewViewProtocol?
    private let interactor: PaydayReviewInteractorProtocol
    private let router: PaydayReviewRouterProtocol
    private let onFinish: (() -> Void)?
    private let plan: FunMoneyPlan
    private var choices: [UUID: ReviewChoice]
    private let initialChoices: [UUID: ReviewChoice]
    private var applied = false

    // Explicit deinit: the synthesized one on a MainActor class with weak refs corrupts the heap in the test host.
    deinit {}

    init(view: PaydayReviewViewProtocol, interactor: PaydayReviewInteractorProtocol,
         router: PaydayReviewRouterProtocol, onFinish: (() -> Void)?) {
        self.view = view
        self.interactor = interactor
        self.router = router
        self.onFinish = onFinish
        let plan = FunMoneyPlan.make(wants: interactor.wants, funMoney: interactor.budget,
                                     timerThreshold: interactor.timerThreshold)
        self.plan = plan
        // Payday wants that fit (best fit in thaw order) are kept, the rest wait. Quick thaws don't count
        // against fun money, so they default to Keep.
        var defaults: [UUID: ReviewChoice] = [:]
        for entry in plan.payday { defaults[entry.want.id] = entry.fits ? .keep : .wait }
        for want in plan.quickThaws { defaults[want.id] = .keep }
        choices = defaults
        initialChoices = defaults
    }

    func viewDidLoad() {
        view?.render(PaydayReviewContent(
            budgetCaption: "Fun money", budgetText: Formatting.sgd(interactor.budget),
            rows: plan.payday.map { row($0.want) },
            quickTitle: "Quick thaws",
            quickRows: plan.quickThaws.map(row)))
        view?.update(summary(), animated: false)
    }

    func setChoice(id: UUID, choice: ReviewChoice) {
        guard !applied else { return }
        choices[id] = choice
        view?.update(summary(), animated: true)
    }

    func tapCTA() {
        guard !applied else { return }
        applied = true
        view?.setCTAEnabled(false)
        interactor.apply(choices: choices)
        view?.playSuccessFeedback()
        if let onFinish {
            onFinish()
        } else {
            router.dismiss()
        }
    }

    func tapClose() {
        guard !applied else { return }
        if choices == initialChoices {
            router.dismiss()
        } else {
            view?.showDiscardConfirmation()
        }
    }

    func confirmDiscard() {
        guard !applied else { return }
        router.dismiss()
    }

    private func row(_ want: Want) -> ReviewRowViewModel {
        let price = Formatting.sgd(want.price)
        let reason = want.reason.isEmpty ? "No reason written." : "\u{201C}\(want.reason)\u{201D}"
        return ReviewRowViewModel(
            id: want.id, name: want.name, reasonText: reason, priceText: price,
            choice: choices[want.id] ?? .wait,
            choiceLabels: [
                "Keep \(want.name), \(price)",
                "Wait on \(want.name) one more payday",
                "Let go of \(want.name), save \(price)",
            ],
            spokenSummary: "\(want.name), \(price). \(reason)")
    }

    private func summary() -> PaydayReviewSummary {
        let wants = plan.ordered
        let kept = wants.filter { choices[$0.id] == .keep }
        let letGo = wants.filter { choices[$0.id] == .letGo }
        let summary = plan.summary(keeping: Set(kept.map(\.id)))
        let isOver = summary.overBy > 0
        let status = isOver ? "\(Formatting.sgd(summary.overBy)) over" : "\(Formatting.sgd(summary.remaining)) left"
        var parts: [String] = []
        if !kept.isEmpty { parts.append("keep \(kept.count)") }
        if !letGo.isEmpty { parts.append("let go \(letGo.count)") }
        let cta = parts.isEmpty ? "Wait on all" : "Done \u{00B7} " + parts.joined(separator: ", ")
        return PaydayReviewSummary(fraction: summary.fraction, isOver: isOver, statusText: status, ctaTitle: cta)
    }
}
