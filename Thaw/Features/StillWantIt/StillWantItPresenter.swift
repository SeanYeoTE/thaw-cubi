import Foundation

final class StillWantItPresenter: StillWantItPresenterProtocol {
    private weak var view: StillWantItViewProtocol?
    private let interactor: StillWantItInteractorProtocol
    private let router: StillWantItRouterProtocol
    private let onFinish: (() -> Void)?
    private var index = 0
    private var boughtTotal: Decimal = 0

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

    func tapSkip() {
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
        let reason = want.reason.isEmpty ? "No reason written." : want.reason
        let ifBuy = budget - boughtTotal - want.price
        view?.render(StillWantItViewModel(
            progressText: "Payday review · \(index + 1) of \(interactor.wants.count)",
            question: "Still want the \(want.name.lowercased())?",
            priceText: Formatting.sgd(want.price),
            quote: "On \(Formatting.paydayDate(want.frozenOn)), you said\n\u{201C}\(reason)\u{201D}",
            funText: "Fun money if you buy: \(Formatting.sgd(ifBuy)) of \(Formatting.sgd(budget)) left",
            keepTitle: "Skip and keep \(Formatting.sgd(want.price))"
        ))
    }
}
