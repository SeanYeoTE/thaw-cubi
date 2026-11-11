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

    func selectFilter(at index: Int) {
        guard CoolingFilter.allCases.indices.contains(index) else { return }
        let filter = CoolingFilter.allCases[index]
        guard filter != interactor.filter else { return }
        interactor.filter = filter
        refresh()
    }

    func selectSort(_ sort: CoolingSort) {
        guard sort != interactor.sort else { return }
        interactor.sort = sort
        refresh()
    }

    func tapShowAll() {
        interactor.filter = .all
        refresh()
    }

    private func coolingWant(_ id: UUID) -> Want? {
        interactor.snapshot().cooling.first { $0.id == id }
    }

    // MARK: - Model

    private func refresh() {
        let snapshot = interactor.snapshot()
        let filter = interactor.filter
        let sort = interactor.sort
        let thawing = snapshot.reviewQueue
        let total = thawing.reduce(Decimal(0)) { $0 + $1.price }
        let subtitle = "\(thawing.count) \(thawing.count == 1 ? "want thaws" : "wants thaw") then · "
            + "\(Formatting.sgd(total)) vs \(Formatting.sgd(snapshot.payday.funMoney)) fun money"

        let threshold = snapshot.settings.timerThreshold
        let sorted = Self.sorted(snapshot.cooling, by: sort)
        let visible = sorted.filter { Self.matches($0, filter: filter, threshold: threshold) }
        let sections = Self.sections(visible, sort: sort, nextPayday: snapshot.payday.nextPayday) {
            self.card(for: $0, settings: snapshot.settings)
        }

        let empty: HomeEmptyViewModel?
        if snapshot.cooling.isEmpty {
            empty = HomeEmptyViewModel(kind: .noWants, line: "Nothing cooling.", actionTitle: "Add a want")
        } else if visible.isEmpty {
            empty = HomeEmptyViewModel(kind: .noMatches, line: Self.noMatchesLine(filter), actionTitle: "Show all")
        } else {
            empty = nil
        }

        view?.render(HomeViewModel(
            daysLeft: snapshot.payday.daysUntilNext,
            nextPaydayText: Formatting.paydayDate(snapshot.payday.nextPayday),
            paydaySubtitle: subtitle,
            hasReview: !thawing.isEmpty,
            filterTitles: CoolingFilter.allCases.map(Self.title(for:)),
            filterIndex: CoolingFilter.allCases.firstIndex(of: filter) ?? 0,
            sortTitle: Self.title(for: sort),
            sortOptions: CoolingSort.allCases.map {
                HomeSortOptionViewModel(sort: $0, title: Self.title(for: $0), isSelected: $0 == sort)
            },
            sections: sections,
            empty: empty,
            cards: sorted.map { card(for: $0, settings: snapshot.settings) }
        ))
    }

    private static func title(for filter: CoolingFilter) -> String {
        switch filter {
        case .all: "All"
        case .payday: "Payday"
        case .quickThaw: "Quick thaw"
        }
    }

    private static func title(for sort: CoolingSort) -> String {
        switch sort {
        case .soonest: "Thaws soonest"
        case .priceHigh: "Price: high to low"
        case .recent: "Recently added"
        case .name: "Name"
        }
    }

    private static func noMatchesLine(_ filter: CoolingFilter) -> String {
        switch filter {
        case .all: "Nothing cooling."
        case .payday: "No payday wants cooling."
        case .quickThaw: "No quick thaws cooling."
        }
    }

    /// Payday wants cost at least the timer threshold; cheaper ones are quick thaws.
    private static func matches(_ want: Want, filter: CoolingFilter, threshold: Decimal) -> Bool {
        switch filter {
        case .all: true
        case .payday: want.price >= threshold
        case .quickThaw: want.price < threshold
        }
    }

    /// Ties fall back to name, then id, so the order never jumps between renders.
    private static func sorted(_ wants: [Want], by sort: CoolingSort) -> [Want] {
        wants.sorted { a, b in
            switch sort {
            case .soonest where a.thawsAt != b.thawsAt: return a.thawsAt < b.thawsAt
            case .priceHigh where a.price != b.price: return a.price > b.price
            case .recent where a.frozenOn != b.frozenOn: return a.frozenOn > b.frozenOn
            default: break
            }
            let byName = a.name.localizedStandardCompare(b.name)
            if byName != .orderedSame { return byName == .orderedAscending }
            return a.id.uuidString < b.id.uuidString
        }
    }

    private static func sections(
        _ wants: [Want], sort: CoolingSort, nextPayday: Date, card: (Want) -> HomeCardViewModel
    ) -> [HomeSectionViewModel] {
        guard !wants.isEmpty else { return [] }
        guard sort == .soonest else { return [HomeSectionViewModel(title: nil, trailing: nil, cards: wants.map(card))] }
        let thisPayday = wants.filter { $0.thawsAt <= nextPayday }
        let later = wants.filter { $0.thawsAt > nextPayday }
        var sections: [HomeSectionViewModel] = []
        if !thisPayday.isEmpty {
            let total = thisPayday.reduce(Decimal(0)) { $0 + $1.price }
            sections.append(HomeSectionViewModel(title: "This payday", trailing: Formatting.sgd(total),
                                                 cards: thisPayday.map(card)))
        }
        if !later.isEmpty {
            sections.append(HomeSectionViewModel(title: "Later", trailing: nil, cards: later.map(card)))
        }
        return sections
    }

    private func card(for want: Want, settings: PaydaySettings) -> HomeCardViewModel {
        let isTimer = want.price < settings.timerThreshold
        let priceText = Formatting.sgd(want.price)
        let days = Self.daysText(until: want.thawsAt)
        let date = Self.spokenDate(want.thawsAt)
        let when = isTimer ? "Quick thaw, thaws \(date)" : "Thaws on payday, \(date)"
        return HomeCardViewModel(id: want.id, name: want.name, priceText: priceText,
                                 progress: want.progress, isTimer: isTimer,
                                 symbol: isTimer ? "timer" : "calendar", trailingText: days,
                                 accessibilityLabel: "\(want.name), \(priceText)",
                                 accessibilityValue: "\(when), \(days)")
    }

    private static func spokenDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_SG")
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: date)
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
