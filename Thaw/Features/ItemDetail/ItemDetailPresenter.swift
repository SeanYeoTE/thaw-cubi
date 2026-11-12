import Foundation

final class ItemDetailPresenter: ItemDetailPresenterProtocol {
    private weak var view: ItemDetailViewProtocol?
    private let interactor: ItemDetailInteractorProtocol
    private let router: ItemDetailRouterProtocol

    // Explicit deinit: the synthesized one on a MainActor class with weak refs corrupts the heap in the test host.
    deinit {}

    init(view: ItemDetailViewProtocol, interactor: ItemDetailInteractorProtocol, router: ItemDetailRouterProtocol) {
        self.view = view
        self.interactor = interactor
        self.router = router
    }

    func viewDidLoad() {
        let want = interactor.want
        let isTimer = want.price < interactor.settings.timerThreshold
        let calendar = Calendar.current
        let days = max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: .now), to: want.thawsAt).day ?? 0)
        let reason = want.reason.isEmpty ? "No reason written." : want.reason
        view?.render(ItemDetailViewModel(
            name: want.name,
            priceText: Formatting.sgd(want.price),
            frozenText: "Frozen \(Self.shortDate(want.frozenOn))",
            daysText: days == 0 ? "Today" : "\(days) \(days == 1 ? "day" : "days")",
            captionText: "\(isTimer ? "Quick thaw" : "Thaws on payday") · \(Self.shortDate(want.thawsAt))",
            progress: want.progress,
            isTimer: isTimer,
            quote: "\u{201C}\(reason)\u{201D}",
            linkText: want.link.map { "Open link · \(Self.displayHost($0))" },
            letGoTitle: "Let go · save \(Formatting.sgd(want.price))"
        ))
    }

    func tapEdit() {
        router.showEdit(wantID: interactor.want.id)
    }

    func tapLink() {
        guard let link = interactor.want.link else { return }
        router.openLink(link)
    }

    func didEdit() {
        guard interactor.wantExists else { return router.pop() }
        viewDidLoad()
    }

    func tapDecide() {
        router.showDecideNow(want: interactor.want)
    }

    func tapLetGo() {
        let name = interactor.want.name
        view?.showLetGoConfirmation(title: "Let go of \(name)?", confirmTitle: "Let go", cancelTitle: "Cancel") { [weak self] in
            self?.confirmLetGo()
        }
    }

    private func confirmLetGo() {
        let price = interactor.want.price
        interactor.skip()
        let line = CubiMood.proudLine(amount: Formatting.sgd(price))
        view?.showSkipMoment(line: line) { [weak self] in self?.router.pop() }
    }

    static func displayHost(_ url: URL) -> String {
        guard let host = url.host(), !host.isEmpty else { return url.absoluteString }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    private static func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_SG")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
}
