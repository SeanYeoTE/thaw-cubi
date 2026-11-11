import Foundation

final class SavedPresenter: SavedPresenterProtocol, SavedInteractorOutput {
    static let emptyLine = "Your savings show up here after payday."
    static let filterTitles = ["All", "Let go", "Bought"]
    static let rangeTitles = ["6M", "1Y", "All"]

    private weak var view: SavedViewProtocol?
    private let interactor: SavedInteractorProtocol
    private let router: SavedRouterProtocol
    private let calendar: Calendar
    private let now: () -> Date
    private var chips: [SavedStatChip] = []

    // Explicit deinit: the synthesized one on a MainActor class with weak refs corrupts the heap in the test host.
    deinit {}

    init(view: SavedViewProtocol, interactor: SavedInteractorProtocol, router: SavedRouterProtocol,
         calendar: Calendar = .current, now: @escaping () -> Date = { .now }) {
        self.view = view
        self.interactor = interactor
        self.router = router
        self.calendar = calendar
        self.now = now
        interactor.output = self
    }

    func viewWillAppear() { refresh() }

    func dataDidChange() { refresh() }

    func tapEdit(id: UUID) {
        guard decidedWant(id) != nil else { return }
        router.showEdit(id: id)
    }

    func tapDelete(id: UUID) {
        guard let want = decidedWant(id) else { return }
        view?.showDeleteConfirmation(id: id, confirmation: SavedDeleteConfirmation(
            title: "Delete \(want.name)?",
            message: "It will be removed from Thaw, including your history and savings total.",
            deleteTitle: "Delete",
            cancelTitle: "Cancel"
        ))
    }

    func confirmDelete(id: UUID) {
        guard interactor.wants.contains(where: { $0.id == id }) else { return }
        interactor.delete(id)
    }

    func tapChip(at index: Int) {
        guard chips.indices.contains(index) else { return }
        view?.showChipExplanation(SavedChipExplanation(message: chips[index].spoken, dismissTitle: "OK"))
    }

    func selectHistoryFilter(at index: Int) {
        let filters = SavedHistoryFilter.allCases
        guard filters.indices.contains(index), filters[index] != interactor.historyFilter else { return }
        interactor.historyFilter = filters[index]
        refresh()
    }

    func selectChartRange(at index: Int) {
        let ranges = SavedChartRange.allCases
        guard ranges.indices.contains(index), ranges[index] != interactor.chartRange else { return }
        interactor.chartRange = ranges[index]
        refresh()
    }

    private func decidedWant(_ id: UUID) -> Want? {
        interactor.wants.first { $0.id == id && $0.status != .cooling }
    }

    // MARK: - Model

    private func refresh() {
        let wants = interactor.wants
        let decided = wants.filter { $0.status != .cooling }
        let stats = ProgressStats.make(wants: wants, funMoney: interactor.funMoney, now: now(), calendar: calendar)
        chips = decided.isEmpty ? [] : makeChips(stats)
        view?.render(SavedViewModel(
            hero: hero(decided: decided.count, stats: stats),
            chips: chips,
            chart: chart(decided),
            empty: decided.isEmpty ? SavedEmptyViewModel(mood: .frozen, line: Self.emptyLine) : nil,
            history: decided.isEmpty ? nil : history(decided)
        ))
    }

    // Mood is a pure function of the stats, so Cubi only changes when the numbers do.
    private func hero(decided: Int, stats: ProgressStats) -> SavedHeroViewModel {
        let mood: CubiMood = decided == 0 ? .frozen : (stats.streak >= 1 ? .proud : .snoozing)
        let saved = Formatting.sgd(stats.saved)
        return SavedHeroViewModel(mood: mood, spokenLine: mood.line, savedText: saved, caption: "saved",
                                  spoken: "\(saved) saved")
    }

    private func makeChips(_ stats: ProgressStats) -> [SavedStatChip] {
        let streak = SavedStatChip(
            symbol: "flame.fill",
            value: "\(stats.streak)",
            caption: "streak",
            spoken: stats.streak == 0
                ? "No streak yet. Skip one want at payday to start a streak."
                : "\(stats.streak) \(stats.streak == 1 ? "payday" : "paydays") in a row. You let a want go at each one."
        )
        let winRate = SavedStatChip(
            symbol: "xmark.circle",
            value: "\(stats.winRatePercent)%",
            caption: "let go",
            spoken: "\(stats.winRatePercent) percent let go. You skipped \(stats.skippedCount) of \(stats.decidedCount) wants you froze."
        )
        let months = stats.funMoneyMonths
        let funMoney: SavedStatChip
        if months >= 1 {
            let value = String(format: "%.1f", months)
            funMoney = SavedStatChip(
                symbol: "banknote", value: value, caption: "months",
                spoken: "\(value) months of fun money. That's what you chose not to spend.")
        } else {
            let value = "\(Int((months * 100).rounded()))%"
            funMoney = SavedStatChip(
                symbol: "banknote", value: value, caption: "of a month",
                spoken: "\(value) of a month's fun money. That's what you chose not to spend.")
        }
        return [streak, winRate, funMoney]
    }

    // MARK: - Chart

    private func chart(_ decided: [Want]) -> SavedChartViewModel {
        let series = monthlySaved(decided)
        let range = interactor.chartRange
        let visible: [SavedMonthlyAmount]
        switch range {
        case .sixMonths: visible = Array(series.suffix(6))
        case .oneYear: visible = Array(series.suffix(12))
        case .all: visible = series
        }
        return SavedChartViewModel(
            months: visible,
            rangeTitles: Self.rangeTitles,
            selectedRange: SavedChartRange.allCases.firstIndex(of: range) ?? 0,
            showsRangePicker: series.count >= 6,
            showsChart: visible.count >= 2 && series.contains { $0.amount > 0 },
            accessibilityLabel: "Saved per month"
        )
    }

    /// Skipped prices per decision month, oldest first, with every month from the first decision to now (empty ones at 0).
    private func monthlySaved(_ decided: [Want]) -> [SavedMonthlyAmount] {
        guard let first = decided.map({ monthStart($0.decisionDate) }).min() else { return [] }
        let current = monthStart(now())
        let last = max(current, decided.map { monthStart($0.decisionDate) }.max() ?? current)
        let totals = savedByMonth(decided)
        var result: [SavedMonthlyAmount] = []
        var month = first
        while month <= last {
            let amount = totals[month] ?? 0
            let money = Formatting.sgd(amount)
            result.append(SavedMonthlyAmount(
                month: month,
                amount: NSDecimalNumber(decimal: amount).doubleValue,
                isCurrent: month == current,
                selectionText: "\(format(month, "MMM")) · \(money)",
                spokenMonth: format(month, "MMMM yyyy"),
                spokenAmount: "\(money) saved"
            ))
            guard let next = calendar.date(byAdding: .month, value: 1, to: month) else { break }
            month = next
        }
        return result
    }

    // MARK: - History

    private func history(_ decided: [Want]) -> SavedHistoryViewModel {
        let filter = interactor.historyFilter
        let shown = decided.filter { want in
            switch filter {
            case .all: true
            case .letGo: want.status == .skipped
            case .bought: want.status == .bought
            }
        }
        let totals = savedByMonth(decided)
        let currentYear = calendar.component(.year, from: now())
        let sections = Dictionary(grouping: shown) { monthStart($0.decisionDate) }
            .sorted { $0.key > $1.key }
            .map { month, wants in
                let saved = totals[month] ?? 0
                return SavedHistorySection(
                    month: month,
                    title: format(month, calendar.component(.year, from: month) == currentYear ? "MMMM" : "MMMM yyyy"),
                    detail: saved > 0 ? "\(Formatting.sgd(saved)) saved" : nil,
                    rows: wants.sorted { $0.decisionDate > $1.decisionDate }.map(row)
                )
            }
        let emptyText: String? = switch (sections.isEmpty, filter) {
        case (true, .letGo): "None let go yet."
        case (true, .bought): "None bought yet."
        case (true, .all): "None yet."
        default: nil
        }
        return SavedHistoryViewModel(
            filterTitles: Self.filterTitles,
            selectedFilter: SavedHistoryFilter.allCases.firstIndex(of: filter) ?? 0,
            sections: sections,
            emptyText: emptyText
        )
    }

    private func row(_ want: Want) -> SavedHistoryRow {
        let price = Formatting.sgd(want.price)
        let outcome = want.status == .skipped ? "Let go" : "Bought"
        return SavedHistoryRow(
            id: want.id,
            name: want.name,
            priceText: price,
            isSkipped: want.status == .skipped,
            accessibilityLabel: "\(want.name), \(price)",
            accessibilityValue: "\(outcome), decided \(format(want.decisionDate, "d MMMM yyyy"))"
        )
    }

    // MARK: - Helpers

    private func savedByMonth(_ decided: [Want]) -> [Date: Decimal] {
        decided.filter { $0.status == .skipped }.reduce(into: [:]) { totals, want in
            totals[monthStart(want.decisionDate), default: 0] += want.price
        }
    }

    private func monthStart(_ date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    private func format(_ date: Date, _ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
