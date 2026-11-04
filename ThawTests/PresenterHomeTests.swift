import XCTest
@testable import Thaw

@MainActor
final class PresenterHomeTests: XCTestCase {
    private final class FakeView: HomeViewProtocol {
        var models: [HomeViewModel] = []
        func render(_ model: HomeViewModel) { models.append(model) }
    }

    private final class FakeInteractor: HomeInteractorProtocol {
        init() {}
        weak var output: HomeInteractorOutput?
        var cooling: [Want] = []
        var queue: [Want] = []
        var summary: MonthEndSummary?
        var dismissed = 0
        func snapshot() -> HomeSnapshot {
            HomeSnapshot(cooling: cooling, reviewQueue: queue,
                         payday: PaydaySchedule(nextPayday: .now.addingTimeInterval(86_400 * 3), funMoney: 300),
                         settings: .default, monthEnd: summary)
        }
        func dismissMonthEndSummary() {
            dismissed += 1
            summary = nil
        }
    }

    private final class FakeRouter: HomeRouterProtocol {
        var calls: [String] = []
        func showAddWant() { calls.append("add") }
        func showPaydayPreview() { calls.append("preview") }
        func showItemDetail(id: UUID) { calls.append("detail") }
        func showSaved(completedGoalId: UUID?) { calls.append("saved \(completedGoalId == nil ? "-" : "goal")") }
    }

    private func make() -> (HomePresenter, FakeView, FakeInteractor, FakeRouter) {
        let view = FakeView(), interactor = FakeInteractor(), router = FakeRouter()
        return (HomePresenter(view: view, interactor: interactor, router: router), view, interactor, router)
    }

    func testEmptyStateDisablesPaydayCard() {
        let (presenter, view, _, _) = make()
        presenter.viewWillAppear()
        let model = view.models.last
        XCTAssertEqual(model?.hasReview, false)
        XCTAssertEqual(model?.emptyText, "Nothing cooling. Add a want to start the wait.")
        XCTAssertEqual(model?.cards.count, 0)
    }

    func testCardsAndSubtitleReflectQueue() {
        let (presenter, view, interactor, _) = make()
        let keyboard = Fixture.want("Keyboard", 189)
        interactor.cooling = [keyboard, Fixture.want("Case", 24)]
        interactor.queue = [keyboard]
        presenter.viewWillAppear()
        let model = view.models.last
        XCTAssertEqual(model?.hasReview, true)
        XCTAssertEqual(model?.paydaySubtitle, "1 want thaws then · S$189 vs S$300 fun money")
        XCTAssertEqual(model?.cards.map(\.isTimer), [false, true])
        XCTAssertNil(model?.emptyText)
    }

    func testPaydayTapIsIgnoredWhenQueueEmpty() {
        let (presenter, _, interactor, router) = make()
        presenter.tapPayday()
        XCTAssertEqual(router.calls, [])
        interactor.queue = [Fixture.want("Keyboard", 189)]
        presenter.tapPayday()
        XCTAssertEqual(router.calls, ["preview"])
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

    private func summary(completed: Bool) -> MonthEndSummary {
        MonthEndSummary(month: .now, pool: 600, skipped: 489, unspent: 111,
                        applied: [.init(goalId: UUID(), goalName: "Espresso", amount: 490, completed: completed),
                                  .init(goalId: UUID(), goalName: "Japan trip", amount: 110, completed: false)],
                        keptRemainder: 0)
    }

    func testNoNoticeWithoutSummary() {
        let (presenter, view, _, _) = make()
        presenter.viewWillAppear()
        XCTAssertNil(view.models.last?.notice)
    }

    func testNoticeShowsMathsInFillOrder() {
        let (presenter, view, interactor, _) = make()
        interactor.summary = summary(completed: true)
        presenter.viewWillAppear()
        let notice = view.models.last?.notice
        XCTAssertTrue(notice?.title.hasSuffix("ended: S$600 landed") ?? false)
        XCTAssertEqual(notice?.lines, ["S$489 skipped + S$111 unspent fun money",
                                       "+S$490 to Espresso · goal reached", "+S$110 to Japan trip"])
        XCTAssertEqual(notice?.completesGoal, true)
    }

    func testDismissNoticeClearsIt() {
        let (presenter, view, interactor, _) = make()
        interactor.summary = summary(completed: false)
        presenter.dismissNotice()
        XCTAssertEqual(interactor.dismissed, 1)
        XCTAssertNil(view.models.last?.notice)
    }

    func testTapNoticeOpensSavedAndGoalCompleteWhenCompleted() {
        let (presenter, _, interactor, router) = make()
        interactor.summary = summary(completed: true)
        presenter.tapNotice()
        XCTAssertEqual(router.calls, ["saved goal"])
        XCTAssertEqual(interactor.dismissed, 1)
    }

    func testTapNoticeOpensOnlySavedWhenNothingCompleted() {
        let (presenter, _, interactor, router) = make()
        interactor.summary = summary(completed: false)
        presenter.tapNotice()
        XCTAssertEqual(router.calls, ["saved -"])
    }
}
