import Foundation

final class PaydayReviewPresenter: PaydayReviewPresenterProtocol {
    private weak var view: PaydayReviewViewProtocol?
    private let interactor: PaydayReviewInteractorProtocol
    private let router: PaydayReviewRouterProtocol
    private let onFinish: (() -> Void)?
    private var choices: [UUID: ReviewChoice]
    private let initialChoices: [UUID: ReviewChoice]

    // Explicit deinit: the synthesized one on a MainActor class with weak refs corrupts the heap in the test host.
    deinit {}

    init(view: PaydayReviewViewProtocol, interactor: PaydayReviewInteractorProtocol,
         router: PaydayReviewRouterProtocol, onFinish: (() -> Void)?) {
        self.view = view
        self.interactor = interactor
        self.router = router
        self.onFinish = onFinish
        // Keep each want that still fits the fun money, in thaw order; the rest wait.
        var spent: Decimal = 0
        var defaults: [UUID: ReviewChoice] = [:]
        for want in interactor.wants {
            if spent + want.price <= interactor.budget {
                spent += want.price
                defaults[want.id] = .keep
            } else {
                defaults[want.id] = .wait
            }
        }
        choices = defaults
        initialChoices = defaults
    }

    func viewDidLoad() {
        let rows = interactor.wants.map { want -> ReviewRowViewModel in
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
        view?.render(PaydayReviewContent(budgetCaption: "Fun money", budgetText: Formatting.sgd(interactor.budget), rows: rows))
        view?.update(summary(), animated: false)
    }

    func setChoice(id: UUID, choice: ReviewChoice) {
        choices[id] = choice
        view?.update(summary(), animated: true)
    }

    func tapCTA() {
        interactor.apply(choices: choices)
        view?.playSuccessFeedback()
        if let onFinish {
            onFinish()
        } else {
            router.dismiss()
        }
    }

    func tapClose() {
        if choices == initialChoices {
            router.dismiss()
        } else {
            view?.showDiscardConfirmation()
        }
    }

    func confirmDiscard() {
        router.dismiss()
    }

    private func summary() -> PaydayReviewSummary {
        let wants = interactor.wants
        let kept = wants.filter { choices[$0.id] == .keep }
        let letGo = wants.filter { choices[$0.id] == .letGo }
        let summary = FunMoneySummary.make(keptPrices: kept.map(\.price), budget: interactor.budget)
        let isOver = summary.overBy > 0
        let status = isOver ? "\(Formatting.sgd(summary.overBy)) over" : "\(Formatting.sgd(summary.remaining)) left"
        var parts: [String] = []
        if !kept.isEmpty { parts.append("keep \(kept.count)") }
        if !letGo.isEmpty { parts.append("let go \(letGo.count)") }
        let cta = parts.isEmpty ? "Wait on all" : "Done \u{00B7} " + parts.joined(separator: ", ")
        return PaydayReviewSummary(fraction: summary.fraction, isOver: isOver, statusText: status, ctaTitle: cta)
    }
}
