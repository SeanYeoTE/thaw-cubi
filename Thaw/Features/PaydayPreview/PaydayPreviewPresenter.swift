import Foundation

final class PaydayPreviewPresenter: PaydayPreviewPresenterProtocol {
    private weak var view: PaydayPreviewViewProtocol?
    private let interactor: PaydayPreviewInteractorProtocol
    private let router: PaydayPreviewRouterProtocol

    init(view: PaydayPreviewViewProtocol, interactor: PaydayPreviewInteractorProtocol, router: PaydayPreviewRouterProtocol) {
        self.view = view
        self.interactor = interactor
        self.router = router
    }

    func viewDidLoad() {
        let queue = interactor.reviewQueue
        let total = queue.reduce(Decimal(0)) { $0 + $1.price }
        view?.render(PaydayPreviewViewModel(
            title: ThawNotification.paydayTitle(count: queue.count),
            body: ThawNotification.paydayBody(total: total, funMoney: interactor.funMoney)))
    }

    func tapReview() {
        let wants = interactor.reviewQueue
        guard !wants.isEmpty else { return }
        router.showReview(wants: wants)
    }

    func tapRemindTonight() {
        view?.setReminderBusy()
        interactor.remindTonight { [weak self] in
            self?.view?.playSuccessFeedback()
            self?.router.dismiss()
        }
    }

    func tapClose() {
        router.dismiss()
    }
}
