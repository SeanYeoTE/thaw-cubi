import XCTest
@testable import Thaw

@MainActor
final class PresenterSavedTests: XCTestCase {
    private final class FakeView: SavedViewProtocol {
        var model: SavedViewModel?
        var renders = 0
        var deleteConfirmation: (id: UUID, confirmation: SavedDeleteConfirmation)?
        var explanation: SavedChipExplanation?
        func render(_ model: SavedViewModel) { self.model = model; renders += 1 }
        func showDeleteConfirmation(id: UUID, confirmation: SavedDeleteConfirmation) {
            deleteConfirmation = (id, confirmation)
        }
        func showChipExplanation(_ explanation: SavedChipExplanation) { self.explanation = explanation }
    }

    private final class FakeInteractor: SavedInteractorProtocol {
        init() {}
        deinit {}
        weak var output: SavedInteractorOutput?
        var wants: [Want] = []
        var funMoney: Decimal = 300
        var historyFilter: SavedHistoryFilter = .all
        var chartRange: SavedChartRange = .sixMonths
        var deleted: [UUID] = []
        func delete(_ id: UUID) { deleted.append(id) }
    }

    private final class FakeRouter: SavedRouterProtocol {
        var edited: [UUID] = []
        func showEdit(id: UUID) { edited.append(id) }
    }

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Singapore")!
        return calendar
    }()

    /// 15 November 2026, noon.
    private var now: Date { date(2026, 11, 15) }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func make(_ wants: [Want], filter: SavedHistoryFilter = .all, range: SavedChartRange = .sixMonths)
        -> (SavedPresenter, FakeView, FakeInteractor, FakeRouter) {
        let view = FakeView(), interactor = FakeInteractor(), router = FakeRouter()
        interactor.wants = wants
        interactor.historyFilter = filter
        interactor.chartRange = range
        let now = self.now
        let presenter = SavedPresenter(view: view, interactor: interactor, router: router,
                                       calendar: calendar, now: { now })
        return (presenter, view, interactor, router)
    }

    private func render(_ wants: [Want], filter: SavedHistoryFilter = .all, range: SavedChartRange = .sixMonths) -> SavedViewModel? {
        let (presenter, view, _, _) = make(wants, filter: filter, range: range)
        presenter.viewWillAppear()
        return view.model
    }

    private func want(_ name: String, _ price: Decimal, _ status: Want.Status,
                      decided: Date? = nil, frozen: Date? = nil) -> Want {
        let decidedOn = status == .cooling ? nil : (decided ?? now)
        let frozenOn = frozen ?? (decidedOn ?? now).addingTimeInterval(-86_400 * 20)
        return Want(id: UUID(), name: name, price: price, reason: "r", frozenOn: frozenOn,
                    progress: 1, status: status, thawsAt: decidedOn ?? now, decidedOn: decidedOn)
    }

    // MARK: - Empty

    func testNothingDecidedShowsEmptyState() {
        let model = render([want("Case", 24, .cooling)])
        XCTAssertEqual(model?.empty, SavedEmptyViewModel(mood: .frozen, line: "Your savings show up here after payday."))
        XCTAssertEqual(model?.hero.mood, .frozen)
        XCTAssertEqual(model?.chips, [])
        XCTAssertNil(model?.history)
        XCTAssertFalse(model?.chart.showsChart ?? true)
    }

    // MARK: - Hero

    func testHeroShowsTheTotalSaved() {
        let model = render([want("Shirt", 69, .skipped), want("Grinder", 420, .skipped), want("Keyboard", 189, .bought)])
        XCTAssertNil(model?.empty)
        XCTAssertEqual(model?.hero.savedText, "S$489")
        XCTAssertEqual(model?.hero.caption, "saved")
        XCTAssertEqual(model?.hero.spoken, "S$489 saved")
    }

    func testCubiIsProudDuringAStreakAndSpeaksOnlyToVoiceOver() {
        let model = render([want("Shirt", 69, .skipped)])
        XCTAssertEqual(model?.hero.mood, .proud)
        XCTAssertEqual(model?.hero.spokenLine, CubiMood.proud.line)
    }

    func testCubiSnoozesWhenStreakIsBroken() {
        let model = render([want("Old", 50, .skipped, decided: date(2026, 6, 3)), want("Keyboard", 189, .bought)])
        XCTAssertEqual(model?.hero.mood, .snoozing)
    }

    // MARK: - Chips

    func testChipsShowStreakLetGoAndFunMoneyMonths() {
        let model = render([want("Shirt", 69, .skipped), want("Grinder", 420, .skipped), want("Keyboard", 189, .bought)])
        let chips = model?.chips ?? []
        XCTAssertEqual(chips.map(\.symbol), ["flame.fill", "xmark.circle", "banknote"])
        XCTAssertEqual(chips.map(\.value), ["1", "67%", "1.6 mo"])
        XCTAssertEqual(chips[0].spoken, "1 payday in a row. You let a want go at each one.")
        XCTAssertEqual(chips[1].spoken, "67 percent let go. You skipped 2 of 3 wants you froze.")
        XCTAssertEqual(chips[2].spoken, "1.6 months of fun money. That's what you chose not to spend.")
    }

    func testFunMoneyChipSwitchesToPercentageBelowOneMonth() {
        XCTAssertEqual(render([want("Exactly", 300, .skipped)])?.chips[2].value, "1.0 mo")
        let below = render([want("Lamp", 120, .skipped)])?.chips[2]
        XCTAssertEqual(below?.value, "40%")
        XCTAssertEqual(below?.symbol, "banknote")
        XCTAssertEqual(below?.spoken, "40% of a month's fun money. That's what you chose not to spend.")
    }

    func testTappingAChipShowsItsSentence() {
        let (presenter, view, _, _) = make([want("Shirt", 69, .skipped)])
        presenter.viewWillAppear()
        presenter.tapChip(at: 1)
        XCTAssertEqual(view.explanation, SavedChipExplanation(
            message: "100 percent let go. You skipped 1 of 1 wants you froze.", dismissTitle: "OK"))
        presenter.tapChip(at: 9)
        XCTAssertEqual(view.explanation?.message, "100 percent let go. You skipped 1 of 1 wants you froze.")
    }

    // MARK: - Chart

    func testMonthlySavedFillsGapsWithZeroAndFlagsTheCurrentMonth() {
        let model = render([
            want("Aug", 100, .skipped, decided: date(2026, 8, 10)),
            want("Bought", 50, .bought, decided: date(2026, 9, 10)),
            want("Nov", 30, .skipped, decided: date(2026, 11, 2)),
        ])
        let months = model?.chart.months ?? []
        XCTAssertEqual(months.map(\.month), [date(2026, 8, 1), date(2026, 9, 1), date(2026, 10, 1), date(2026, 11, 1)].map(monthStart))
        XCTAssertEqual(months.map(\.amount), [100, 0, 0, 30])
        XCTAssertEqual(months.map(\.isCurrent), [false, false, false, true])
        XCTAssertEqual(months.first?.selectionText, "Aug · S$100")
        XCTAssertEqual(months.first?.spokenMonth, "August 2026")
        XCTAssertEqual(months.first?.spokenAmount, "S$100 saved")
        XCTAssertTrue(model?.chart.showsChart ?? false)
        XCTAssertFalse(model?.chart.showsRangePicker ?? true)
    }

    func testRangeLimitsTheMonthsShown() {
        let wants = [want("Old", 100, .skipped, decided: date(2025, 3, 10)), want("New", 30, .skipped)]
        XCTAssertEqual(render(wants, range: .sixMonths)?.chart.months.count, 6)
        XCTAssertEqual(render(wants, range: .oneYear)?.chart.months.count, 12)
        let all = render(wants, range: .all)?.chart
        XCTAssertEqual(all?.months.count, 21)
        XCTAssertEqual(all?.selectedRange, 2)
        XCTAssertEqual(all?.rangeTitles, ["6M", "1Y", "All"])
        XCTAssertTrue(all?.showsRangePicker ?? false)
        XCTAssertEqual(render(wants, range: .sixMonths)?.chart.months.last?.isCurrent, true)
    }

    func testSelectingARangeIsStoredAndRerenders() {
        let (presenter, view, interactor, _) = make([want("Old", 100, .skipped, decided: date(2025, 3, 10))])
        presenter.viewWillAppear()
        presenter.selectChartRange(at: 1)
        XCTAssertEqual(interactor.chartRange, .oneYear)
        XCTAssertEqual(view.model?.chart.months.count, 12)
        XCTAssertEqual(view.renders, 2)
        presenter.selectChartRange(at: 7)
        XCTAssertEqual(view.renders, 2)
    }

    func testChartNeedsTwoMonthsInRange() {
        XCTAssertFalse(render([want("Shirt", 69, .skipped)])?.chart.showsChart ?? true)
    }

    // MARK: - History

    func testHistoryIsGroupedByDecisionMonthNewestFirstWithSkippedTotals() {
        let model = render([
            want("Lamp", 45, .bought, decided: date(2026, 9, 3)),
            want("Earbuds", 159, .skipped, decided: date(2026, 9, 20)),
            want("Keyboard", 189, .bought, decided: date(2026, 11, 1)),
            want("Shirt", 69, .skipped, decided: date(2026, 11, 3)),
            want("Grinder", 420, .bought, decided: date(2026, 10, 3)),
            want("Old", 10, .skipped, decided: date(2025, 12, 3)),
            want("Cooling", 20, .cooling),
        ])
        let sections = model?.history?.sections ?? []
        XCTAssertEqual(sections.map(\.title), ["November", "October", "September", "December 2025"])
        XCTAssertEqual(sections.map(\.detail), ["S$69 saved", nil, "S$159 saved", "S$10 saved"])
        XCTAssertEqual(sections.map { $0.rows.map(\.name) }, [["Shirt", "Keyboard"], ["Grinder"], ["Earbuds", "Lamp"], ["Old"]])
    }

    func testWantFrozenInMarchAndDecidedInMayIsInMay() {
        let model = render([
            want("Bag", 200, .skipped, decided: date(2026, 5, 10), frozen: date(2026, 3, 5)),
            want("Mug", 10, .skipped, decided: date(2026, 3, 20)),
        ], range: .all)
        XCTAssertEqual(model?.history?.sections.map(\.title), ["May", "March"])
        XCTAssertEqual(model?.history?.sections.first?.rows.map(\.name), ["Bag"])
        let may = model?.chart.months.first { $0.month == monthStart(date(2026, 5, 1)) }
        XCTAssertEqual(may?.amount, 200)
        XCTAssertEqual(model?.chart.months.first?.amount, 10)
    }

    func testRowsAreLeanWithOutcomeAndDateForVoiceOver() {
        let shirt = want("Shirt", 69, .skipped, decided: date(2026, 11, 3))
        let row = render([shirt, want("Keyboard", 189, .bought, decided: date(2026, 11, 1))])?.history?.rows
        XCTAssertEqual(row?.first, SavedHistoryRow(
            id: shirt.id, name: "Shirt", priceText: "S$69", isSkipped: true,
            accessibilityLabel: "Shirt, S$69", accessibilityValue: "Let go, decided 3 November 2026"))
        XCTAssertEqual(row?.last?.accessibilityValue, "Bought, decided 1 November 2026")
    }

    func testFiltersAllLetGoAndBought() {
        let wants = [want("Shirt", 69, .skipped), want("Keyboard", 189, .bought, decided: date(2026, 11, 1))]
        XCTAssertEqual(render(wants, filter: .all)?.history?.rows.map(\.name), ["Shirt", "Keyboard"])
        XCTAssertEqual(render(wants, filter: .letGo)?.history?.rows.map(\.name), ["Shirt"])
        let bought = render(wants, filter: .bought)?.history
        XCTAssertEqual(bought?.rows.map(\.name), ["Keyboard"])
        XCTAssertEqual(bought?.selectedFilter, 2)
        XCTAssertEqual(bought?.filterTitles, ["All", "Let go", "Bought"])
        XCTAssertEqual(bought?.sections.first?.detail, "S$69 saved")
        XCTAssertNil(bought?.emptyText)
    }

    func testFilterWithNoMatchesShowsShortLine() {
        let history = render([want("Shirt", 69, .skipped)], filter: .bought)?.history
        XCTAssertEqual(history?.sections, [])
        XCTAssertEqual(history?.emptyText, "None bought yet.")
    }

    func testSelectingAFilterIsStoredAndRerenders() {
        let (presenter, view, interactor, _) = make([want("Shirt", 69, .skipped), want("Keyboard", 189, .bought)])
        presenter.viewWillAppear()
        presenter.selectHistoryFilter(at: 1)
        XCTAssertEqual(interactor.historyFilter, .letGo)
        XCTAssertEqual(view.model?.history?.rows.map(\.name), ["Shirt"])
        presenter.selectHistoryFilter(at: 1)
        presenter.selectHistoryFilter(at: -1)
        XCTAssertEqual(view.renders, 2)
    }

    func testHistoryRowsCarryWantIDs() {
        let shirt = want("Shirt", 69, .skipped)
        XCTAssertEqual(render([shirt])?.history?.rows.map(\.id), [shirt.id])
    }

    // MARK: - Updates and actions

    func testDataChangeRerendersWithLatestWants() {
        let (presenter, view, interactor, _) = make([want("Shirt", 69, .cooling)])
        presenter.viewWillAppear()
        XCTAssertTrue(interactor.output === presenter)
        interactor.wants = [want("Shirt", 69, .skipped)]
        interactor.output?.dataDidChange()
        XCTAssertEqual(view.renders, 2)
        XCTAssertEqual(view.model?.hero.savedText, Formatting.sgd(69))
        XCTAssertEqual(view.model?.history?.rows.map(\.name), ["Shirt"])
    }

    func testEditOpensTheEditScreenForDecidedWants() {
        let shirt = want("Shirt", 69, .skipped)
        let (presenter, _, _, router) = make([shirt])
        presenter.tapEdit(id: shirt.id)
        XCTAssertEqual(router.edited, [shirt.id])
    }

    func testEditIgnoresCoolingAndUnknownWants() {
        let cooling = want("Case", 24, .cooling)
        let (presenter, _, _, router) = make([cooling])
        presenter.tapEdit(id: cooling.id)
        presenter.tapEdit(id: UUID())
        XCTAssertTrue(router.edited.isEmpty)
    }

    func testDeleteAsksBeforeDeleting() {
        let shirt = want("Shirt", 69, .skipped)
        let (presenter, view, interactor, _) = make([shirt])
        presenter.tapDelete(id: shirt.id)
        XCTAssertEqual(view.deleteConfirmation?.id, shirt.id)
        XCTAssertEqual(view.deleteConfirmation?.confirmation.title, "Delete Shirt?")
        XCTAssertEqual(view.deleteConfirmation?.confirmation.deleteTitle, "Delete")
        XCTAssertTrue(interactor.deleted.isEmpty)
        presenter.confirmDelete(id: shirt.id)
        XCTAssertEqual(interactor.deleted, [shirt.id])
    }

    func testConfirmDeleteIgnoresUnknownWant() {
        let (presenter, _, interactor, _) = make([want("Shirt", 69, .skipped)])
        presenter.confirmDelete(id: UUID())
        XCTAssertTrue(interactor.deleted.isEmpty)
    }

    private func monthStart(_ date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
    }
}
