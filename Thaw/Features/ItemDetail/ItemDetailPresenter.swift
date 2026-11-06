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
            subtitle: "\(Formatting.sgd(want.price)) · frozen \(Formatting.paydayDate(want.frozenOn))",
            daysText: "\(days) \(days == 1 ? "day" : "days")",
            untilText: "\(isTimer ? "until it thaws" : "until payday") · \(Formatting.paydayDate(want.thawsAt))",
            progress: want.progress,
            isTimer: isTimer,
            quote: "\u{201C}\(reason)\u{201D}",
            thawsText: "Thaws · \(isTimer ? "Timer" : "Payday") · \(Formatting.paydayDate(want.thawsAt)) · \(Self.timeText(want.thawsAt))",
            linkText: want.link.map { "Open link · \(Self.displayHost($0))" }
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
        viewDidLoad()
    }

    func tapWait() {
        interactor.waitOnePayday()
        router.pop()
    }

    func tapDecide() {
        router.showDecideNow(want: interactor.want)
    }

    func tapSkip() {
        interactor.skip()
        let line = CubiMood.proudLine(amount: Formatting.sgd(interactor.want.price))
        view?.showSkipMoment(line: line) { [weak self] in self?.router.pop() }
    }

    static func displayHost(_ url: URL) -> String {
        guard let host = url.host(), !host.isEmpty else { return url.absoluteString }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    private static func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_SG")
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date).lowercased()
    }
}
