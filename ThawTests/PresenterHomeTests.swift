import XCTest
@testable import Thaw

@MainActor
final class PresenterHomeTests: XCTestCase {
    private final class FakeView: HomeViewProtocol {
        var models: [HomeViewModel] = []
        var confirmation: (id: UUID, confirmation: HomeDeleteConfirmation)?
        func render(_ model: HomeViewModel) { models.append(model) }
        func showDeleteConfirmation(id: UUID, confirmation: HomeDeleteConfirmation) { self.confirmation = (id, confirmation) }
    }

    private final class FakeInteractor: HomeInteractorProtocol {
        init() {}
        weak var output: HomeInteractorOutput?
        var cooling: [Want] = []
        var deleted: [UUID] = []
        var nextPayday: Date = .now.addingTimeInterval(86_400 * 3)
        var filter: CoolingFilter = .all
        var sort: CoolingSort = .soonest
        func delete(_ id: UUID) { deleted.append(id) }
        func snapshot() -> HomeSnapshot {
            HomeSnapshot(cooling: cooling, payday: PaydaySchedule(nextPayday: nextPayday, funMoney: 300),
                         settings: .default)
        }
    }

    private final class FakeRouter: HomeRouterProtocol {
        var calls: [String] = []
        func showAddWant() { calls.append("add") }
        func showItemDetail(id: UUID) { calls.append("detail") }
        func showEdit(id: UUID) { calls.append("edit") }
    }

    private func make() -> (HomePresenter, FakeView, FakeInteractor, FakeRouter) {
        let view = FakeView(), interactor = FakeInteractor(), router = FakeRouter()
        return (HomePresenter(view: view, interactor: interactor, router: router), view, interactor, router)
    }

    func testNoWantsShowsTheEmptyState() {
        let (presenter, view, _, _) = make()
        presenter.viewWillAppear()
        let model = view.models.last
        XCTAssertEqual(model?.empty, HomeEmptyViewModel(kind: .noWants, line: "Nothing cooling.", actionTitle: "Add a want"))
        XCTAssertEqual(model?.cards.count, 0)
        XCTAssertEqual(model?.sections, [])
    }

    func testCardsSplitIntoTimerAndPayday() {
        let (presenter, view, interactor, _) = make()
        let keyboard = Fixture.want("Keyboard", 189)
        interactor.cooling = [keyboard, Fixture.want("Case", 24)]
        presenter.viewWillAppear()
        let model = view.models.last
        XCTAssertEqual(model?.cards.first { $0.name == "Keyboard" }?.isTimer, false)
        XCTAssertEqual(model?.cards.first { $0.name == "Case" }?.isTimer, true)
        XCTAssertNil(model?.empty)
    }

    func testDataChangeRerenders() {
        let (presenter, view, _, _) = make()
        presenter.dataDidChange()
        XCTAssertEqual(view.models.count, 1)
    }

    func testAddAndWantTapsRoute() {
        let (presenter, _, _, router) = make()
        presenter.tapAdd()
        presenter.tapWant(id: UUID())
        XCTAssertEqual(router.calls, ["add", "detail"])
    }

    func testEditOpensEditorOnlyForACoolingWant() {
        let (presenter, _, interactor, router) = make()
        let keyboard = Fixture.want("Keyboard", 189)
        interactor.cooling = [keyboard]
        presenter.tapEdit(id: UUID())
        XCTAssertEqual(router.calls, [])
        presenter.tapEdit(id: keyboard.id)
        XCTAssertEqual(router.calls, ["edit"])
    }

    func testDeleteAsksBeforeDeleting() {
        let (presenter, view, interactor, _) = make()
        let keyboard = Fixture.want("Keyboard", 189)
        interactor.cooling = [keyboard]
        presenter.tapDelete(id: keyboard.id)
        XCTAssertEqual(view.confirmation?.id, keyboard.id)
        XCTAssertEqual(view.confirmation?.confirmation.title, "Delete Keyboard?")
        XCTAssertTrue(interactor.deleted.isEmpty)
        presenter.confirmDelete(id: keyboard.id)
        XCTAssertEqual(interactor.deleted, [keyboard.id])
    }

    func testDeleteIgnoresUnknownWants() {
        let (presenter, view, interactor, _) = make()
        presenter.tapDelete(id: UUID())
        presenter.confirmDelete(id: UUID())
        XCTAssertNil(view.confirmation)
        XCTAssertTrue(interactor.deleted.isEmpty)
    }

    func testCardsCarryTimeLeftSymbolAndSpokenDetail() {
        let (presenter, view, interactor, _) = make()
        var timer = Fixture.want("Case", 24)
        timer.thawsAt = Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now
        var soon = Fixture.want("Keyboard", 189)
        soon.thawsAt = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
        interactor.cooling = [timer, soon, Fixture.want("Today", 100)]
        presenter.viewWillAppear()
        let cards = view.models.last?.cards
        XCTAssertEqual(cards?.map(\.name), ["Today", "Keyboard", "Case"])
        XCTAssertEqual(cards?.map(\.trailingText), ["Today", "1 day", "2 days"])
        XCTAssertEqual(cards?.map(\.symbol), ["calendar", "calendar", "timer"])
        XCTAssertEqual(cards?[1].accessibilityLabel, "Keyboard, S$189")
        let date = Self.spoken(soon.thawsAt)
        XCTAssertEqual(cards?[1].accessibilityValue, "Thaws on payday, \(date), 1 day")
        XCTAssertEqual(cards?[2].accessibilityValue, "Quick thaw, thaws \(Self.spoken(timer.thawsAt)), 2 days")
    }

    private static func spoken(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_SG")
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: date)
    }

    // MARK: - Filter

    private func want(_ name: String, _ price: Decimal, days: Int = 1, addedDaysAgo: Int = 0) -> Want {
        var want = Fixture.want(name, price)
        // A fixed base, so wants built a few microseconds apart still tie.
        let base = Calendar.current.date(byAdding: .hour, value: 12, to: Calendar.current.startOfDay(for: .now)) ?? .now
        want.thawsAt = Calendar.current.date(byAdding: .day, value: days, to: base) ?? base
        want.frozenOn = Calendar.current.date(byAdding: .day, value: -addedDaysAgo, to: base) ?? base
        return want
    }

    private func visibleNames(_ view: FakeView) -> [String] {
        view.models.last?.sections.flatMap(\.cards).map(\.name) ?? []
    }

    func testFiltersSplitOnTheTimerThreshold() {
        let (presenter, view, interactor, _) = make()
        // Default threshold is S$30: exactly S$30 counts as Payday.
        interactor.cooling = [want("Edge", 30), want("Cheap", 29.99), want("Big", 189)]
        presenter.viewWillAppear()
        XCTAssertEqual(view.models.last?.filterTitles, ["All", "Payday", "Quick thaw"])
        XCTAssertEqual(view.models.last?.filterIndex, 0)
        XCTAssertEqual(Set(visibleNames(view)), ["Edge", "Cheap", "Big"])

        presenter.selectFilter(at: 1)
        XCTAssertEqual(interactor.filter, .payday)
        XCTAssertEqual(view.models.last?.filterIndex, 1)
        XCTAssertEqual(Set(visibleNames(view)), ["Edge", "Big"])

        presenter.selectFilter(at: 2)
        XCTAssertEqual(interactor.filter, .quickThaw)
        XCTAssertEqual(visibleNames(view), ["Cheap"])
        XCTAssertEqual(view.models.last?.cards.count, 3, "cards ignores the filter")
    }

    func testOutOfRangeFilterIndexIsIgnored() {
        let (presenter, view, interactor, _) = make()
        presenter.selectFilter(at: 7)
        XCTAssertEqual(interactor.filter, .all)
        XCTAssertTrue(view.models.isEmpty)
    }

    func testFilterAndSortAreReadFromTheInteractor() {
        let (presenter, view, interactor, _) = make()
        interactor.filter = .quickThaw
        interactor.sort = .name
        interactor.cooling = [want("Mug", 12), want("Bag", 140)]
        presenter.viewWillAppear()
        let model = view.models.last
        XCTAssertEqual(model?.filterIndex, 2)
        XCTAssertEqual(model?.sortTitle, "Name")
        XCTAssertEqual(model?.sortOptions.filter(\.isSelected).map(\.sort), [.name])
        XCTAssertEqual(visibleNames(view), ["Mug"])
    }

    func testNoMatchesShowsOneLineAndShowAllResets() {
        let (presenter, view, interactor, _) = make()
        interactor.cooling = [want("Bag", 140)]
        interactor.filter = .quickThaw
        presenter.viewWillAppear()
        XCTAssertEqual(view.models.last?.empty,
                       HomeEmptyViewModel(kind: .noMatches, line: "No quick thaws cooling.", actionTitle: "Show all"))
        XCTAssertEqual(view.models.last?.sections, [])

        presenter.tapShowAll()
        XCTAssertEqual(interactor.filter, .all)
        XCTAssertNil(view.models.last?.empty)
        XCTAssertEqual(visibleNames(view), ["Bag"])

        interactor.cooling = [want("Mug", 12)]
        presenter.selectFilter(at: 1)
        XCTAssertEqual(view.models.last?.empty?.line, "No payday wants cooling.")
    }

    // MARK: - Sort

    func testSortOptionsListEveryChoiceWithOneSelected() {
        let (presenter, view, _, _) = make()
        presenter.viewWillAppear()
        XCTAssertEqual(view.models.last?.sortOptions.map(\.title),
                       ["Thaws soonest", "Price: high to low", "Recently added", "Name"])
        XCTAssertEqual(view.models.last?.sortOptions.map(\.isSelected), [true, false, false, false])
    }

    func testEachSortOrdersAndBreaksTiesByName() {
        let (presenter, view, interactor, _) = make()
        interactor.nextPayday = .now.addingTimeInterval(86_400 * 30)
        interactor.cooling = [
            want("bravo", 50, days: 5, addedDaysAgo: 1),
            want("Alpha", 50, days: 5, addedDaysAgo: 3),
            want("Charlie", 200, days: 2, addedDaysAgo: 1),
            want("Delta", 10, days: 9, addedDaysAgo: 0),
        ]
        presenter.viewWillAppear()
        XCTAssertEqual(visibleNames(view), ["Charlie", "Alpha", "bravo", "Delta"])

        presenter.selectSort(.priceHigh)
        XCTAssertEqual(interactor.sort, .priceHigh)
        XCTAssertEqual(visibleNames(view), ["Charlie", "Alpha", "bravo", "Delta"])

        presenter.selectSort(.recent)
        XCTAssertEqual(visibleNames(view), ["Delta", "bravo", "Charlie", "Alpha"])

        presenter.selectSort(.name)
        XCTAssertEqual(visibleNames(view), ["Alpha", "bravo", "Charlie", "Delta"])
        XCTAssertEqual(view.models.last?.sortOptions.map(\.isSelected), [false, false, false, true])
    }

    func testIdenticalWantsKeepAStableOrder() {
        let (presenter, view, interactor, _) = make()
        let a = want("Same", 50)
        var b = want("Same", 50)
        b.thawsAt = a.thawsAt
        b.frozenOn = a.frozenOn
        let expected = [a, b].map(\.id).sorted { $0.uuidString < $1.uuidString }
        for sort in CoolingSort.allCases {
            interactor.sort = sort
            interactor.cooling = [a, b]
            presenter.viewWillAppear()
            XCTAssertEqual(view.models.last?.sections.flatMap(\.cards).map(\.id), expected, "\(sort)")
            interactor.cooling = [b, a]
            presenter.viewWillAppear()
            XCTAssertEqual(view.models.last?.sections.flatMap(\.cards).map(\.id), expected, "\(sort)")
        }
    }

    // MARK: - Sections

    func testSoonestSplitsThisPaydayAndLaterWithTotal() {
        let (presenter, view, interactor, _) = make()
        let payday = Calendar.current.date(byAdding: .day, value: 10, to: .now) ?? .now
        interactor.nextPayday = payday
        var onPayday = want("Keyboard", 189)
        onPayday.thawsAt = payday
        interactor.cooling = [want("Lamp", 45, days: 20), onPayday, want("Case", 24, days: 2), want("Mug", 69, days: 40)]
        presenter.viewWillAppear()
        let sections = view.models.last?.sections
        XCTAssertEqual(sections?.map(\.title), ["This payday", "Later"])
        XCTAssertEqual(sections?.map(\.trailing), ["S$213", nil])
        XCTAssertEqual(sections?[0].cards.map(\.name), ["Case", "Keyboard"])
        XCTAssertEqual(sections?[1].cards.map(\.name), ["Lamp", "Mug"])
    }

    func testSoonestOmitsEmptySections() {
        let (presenter, view, interactor, _) = make()
        interactor.cooling = [want("Lamp", 45, days: 20)]
        presenter.viewWillAppear()
        XCTAssertEqual(view.models.last?.sections.map(\.title), ["Later"])
    }

    func testOtherSortsGiveOneUntitledSection() {
        let (presenter, view, interactor, _) = make()
        interactor.cooling = [want("Lamp", 45, days: 20), want("Case", 24, days: 2)]
        for sort in [CoolingSort.priceHigh, .recent, .name] {
            presenter.selectSort(sort)
            let sections = view.models.last?.sections
            XCTAssertEqual(sections?.count, 1)
            XCTAssertNil(sections?.first?.title)
            XCTAssertNil(sections?.first?.trailing)
            XCTAssertEqual(sections?.first?.cards.count, 2)
        }
    }

    // MARK: - Interactor persistence

    func testInteractorRemembersFilterAndSort() throws {
        let suite = "PresenterHomeTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let store = WantStore(fileURL: nil)
        let reminders = Reminders(store: store)
        let interactor = HomeInteractor(store: store, reminders: reminders, defaults: defaults)
        XCTAssertEqual(interactor.filter, .all)
        XCTAssertEqual(interactor.sort, .soonest)

        interactor.filter = .quickThaw
        interactor.sort = .priceHigh
        XCTAssertEqual(defaults.string(forKey: "cooling.filter"), "quickThaw")
        XCTAssertEqual(defaults.string(forKey: "cooling.sort"), "priceHigh")
        let relaunched = HomeInteractor(store: store, reminders: reminders, defaults: defaults)
        XCTAssertEqual(relaunched.filter, .quickThaw)
        XCTAssertEqual(relaunched.sort, .priceHigh)

        defaults.set("bogus", forKey: "cooling.filter")
        defaults.set("bogus", forKey: "cooling.sort")
        XCTAssertEqual(relaunched.filter, .all)
        XCTAssertEqual(relaunched.sort, .soonest)
    }

    /// Launching on another tab (`-thawTab payday`) leaves Home's view unloaded; a decision made there posts a
    /// DataChange, which used to render into the unloaded view and trap on the nil diffable data source.
    func testDataChangeBeforeHomeViewLoadsDoesNotCrash() {
        let interactor = FakeInteractor()
        interactor.cooling = [Fixture.want("Linen overshirt", 69), Fixture.want("Case", 24)]
        let view = HomeViewController()
        let presenter = HomePresenter(view: view, interactor: interactor, router: FakeRouter())
        view.presenter = presenter

        presenter.dataDidChange()
        XCTAssertFalse(view.isViewLoaded, "Rendering must not force Home's view to load")

        view.loadViewIfNeeded()
        view.beginAppearanceTransition(true, animated: false)
        view.endAppearanceTransition()
        presenter.dataDidChange()
        XCTAssertTrue(view.isViewLoaded)
    }

    /// Mirrors Let go: the want moves from this payday to a later one, and must then sit in exactly one section.
    func testEachWantAppearsInExactlyOneSectionAfterItMovesToLater() {
        let (presenter, view, interactor, _) = make()
        var shirt = Fixture.want("Linen overshirt", 69)
        var keyboard = Fixture.want("Keyboard", 189)
        shirt.thawsAt = .now.addingTimeInterval(-3_600)
        keyboard.thawsAt = shirt.thawsAt
        interactor.cooling = [shirt, keyboard]
        presenter.viewWillAppear()

        var moved = shirt
        moved.thawsAt = interactor.nextPayday.addingTimeInterval(86_400 * 30)
        interactor.cooling = [moved, keyboard]
        presenter.dataDidChange()

        let ids = view.models.last?.sections.flatMap(\.cards).map(\.id) ?? []
        XCTAssertEqual(ids.count, Set(ids).count)
        XCTAssertEqual(Set(ids), [shirt.id, keyboard.id])
        XCTAssertEqual(view.models.last?.sections.map(\.title), ["This payday", "Later"])
    }
}
