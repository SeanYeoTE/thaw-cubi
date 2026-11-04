import Foundation

final class PaydayReviewPresenter: PaydayReviewPresenterProtocol {
    private weak var view: PaydayReviewViewProtocol?
    private let interactor: PaydayReviewInteractorProtocol
    private let router: PaydayReviewRouterProtocol
    private let onFinish: (() -> Void)?
    private var keeping: Set<UUID>
    private let initialKeeping: Set<UUID>

    // Explicit deinit: the synthesized one on a MainActor class with weak refs corrupts the heap in the test host.
    deinit {}

    init(view: PaydayReviewViewProtocol, interactor: PaydayReviewInteractorProtocol,
         router: PaydayReviewRouterProtocol, onFinish: (() -> Void)?) {
        self.view = view
        self.interactor = interactor
        self.router = router
        self.onFinish = onFinish
        if let first = interactor.wants.first, first.price <= interactor.budget {
            keeping = [first.id]
        } else {
            keeping = []
        }
        initialKeeping = keeping
    }

    func viewDidLoad() {
        let rows = interactor.wants.map { want in
            ReviewRowViewModel(
                id: want.id, name: want.name,
                reasonText: want.reason.isEmpty ? "No reason written." : "\u{201C}\(want.reason)\u{201D}",
                priceText: Formatting.sgd(want.price), isKeeping: keeping.contains(want.id))
        }
        view?.render(PaydayReviewContent(budgetText: Formatting.sgd(interactor.budget), rows: rows))
        view?.update(summary(), animated: false)
    }

    func setKeeping(id: UUID, keeping isKeeping: Bool) {
        if isKeeping { keeping.insert(id) } else { keeping.remove(id) }
        view?.update(summary(), animated: true)
    }

    func tapCTA() {
        interactor.apply(keeping: keeping)
        view?.playSuccessFeedback()
        if let onFinish {
            onFinish()
        } else {
            router.dismiss()
        }
    }

    func tapClose() {
        if keeping == initialKeeping {
            router.dismiss()
        } else {
            view?.showDiscardConfirmation()
        }
    }

    func confirmDiscard() {
        router.dismiss()
    }

    private func summary() -> PaydayReviewSummary {
        let kept = interactor.wants.filter { keeping.contains($0.id) }
        let summary = FunMoneySummary.make(keptPrices: kept.map(\.price), budget: interactor.budget)
        let isOver = summary.overBy > 0
        let status = isOver
            ? "\(Formatting.sgd(summary.kept)) kept · \(Formatting.sgd(summary.overBy)) over your fun money"
            : "\(Formatting.sgd(summary.kept)) kept · \(Formatting.sgd(summary.remaining)) left"
        return PaydayReviewSummary(
            fraction: summary.fraction, isOver: isOver, statusText: status,
            ctaTitle: kept.isEmpty ? "Wait on all" : "Keep \(kept.count) · \(Formatting.sgd(summary.kept))")
    }
}
