import Foundation

final class HomePresenter: HomePresenterProtocol, HomeInteractorOutput {
    private weak var view: HomeViewProtocol?
    private let interactor: HomeInteractorProtocol
    private let router: HomeRouterProtocol

    // Explicit deinit: the synthesized one on a MainActor class with weak refs corrupts the heap in the test host.
    deinit {}

    init(view: HomeViewProtocol, interactor: HomeInteractorProtocol, router: HomeRouterProtocol) {
        self.view = view
        self.interactor = interactor
        self.router = router
        interactor.output = self
    }

    func viewWillAppear() { refresh() }

    func dataDidChange() { refresh() }

    func tapAdd() { router.showAddWant() }

    func tapPayday() {
        guard !interactor.snapshot().reviewQueue.isEmpty else { return }
        router.showPaydayPreview()
    }

    func tapWant(id: UUID) { router.showItemDetail(id: id) }

    func tapEdit(id: UUID) {
        guard coolingWant(id) != nil else { return }
        router.showEdit(id: id)
    }

    func tapDelete(id: UUID) {
        guard let want = coolingWant(id) else { return }
        view?.showDeleteConfirmation(id: id, confirmation: HomeDeleteConfirmation(
            title: "Delete \(want.name)?",
            message: "It will be removed from Thaw and won't thaw or show up in your review.",
            deleteTitle: "Delete",
            cancelTitle: "Cancel"
        ))
    }

    func confirmDelete(id: UUID) {
        guard coolingWant(id) != nil else { return }
        interactor.delete(id)
    }

    private func coolingWant(_ id: UUID) -> Want? {
        interactor.snapshot().cooling.first { $0.id == id }
    }

    private func refresh() {
        let snapshot = interactor.snapshot()
        let thawing = snapshot.reviewQueue
        let total = thawing.reduce(Decimal(0)) { $0 + $1.price }
        let subtitle = "\(thawing.count) \(thawing.count == 1 ? "want thaws" : "wants thaw") then · "
            + "\(Formatting.sgd(total)) vs \(Formatting.sgd(snapshot.payday.funMoney)) fun money"
        let cards = snapshot.cooling.map { card(for: $0, settings: snapshot.settings) }
        view?.render(HomeViewModel(
            daysLeft: snapshot.payday.daysUntilNext,
            nextPaydayText: Formatting.paydayDate(snapshot.payday.nextPayday),
            paydaySubtitle: subtitle,
            hasReview: !thawing.isEmpty,
            cards: cards,
            emptyText: cards.isEmpty ? "Nothing cooling. Add a want to start the wait." : nil
        ))
    }

    private func card(for want: Want, settings: PaydaySettings) -> HomeCardViewModel {
        let isTimer = want.price < settings.timerThreshold
        let status = isTimer
            ? "\(settings.timerDays)-day timer · \(Formatting.paydayDate(want.thawsAt))"
            : "Payday · \(Formatting.paydayDate(want.thawsAt))"
        return HomeCardViewModel(id: want.id, name: want.name, priceText: Formatting.sgd(want.price),
                                 progress: want.progress, isTimer: isTimer, statusText: status,
                                 trailingText: Self.daysText(until: want.thawsAt))
    }

    private static func daysText(until date: Date) -> String {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: .now), to: date).day ?? 0
        switch days {
        case ...0: return "Today"
        case 1: return "1 day"
        default: return "\(days) days"
        }
    }
}
