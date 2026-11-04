import XCTest
@testable import Thaw

@MainActor
final class PresenterSavedTests: XCTestCase {
    private final class FakeView: SavedViewProtocol {
        var models: [SavedViewModel] = []
        func render(_ model: SavedViewModel) { models.append(model) }
    }

    private final class FakeInteractor: SavedInteractorProtocol {
        init() {}
        weak var output: SavedInteractorOutput?
        var wants: [Want] = []
        var activeGoals: [Goal] = []
        var finishedGoals: [Goal] = []
        var inviteHiddenUntil: Date?
        var pool = PendingPool(skipped: 0, unspent: 0, total: 0)
        func pendingPool(now: Date) -> PendingPool { pool }
        func hideInvite(until: Date) { inviteHiddenUntil = until }
    }

    private final class FakeRouter: SavedRouterProtocol {
        var calls: [String] = []
        func showGoalDetail(id: UUID) { calls.append("detail") }
        func showGoalEditor() { calls.append("editor") }
    }

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func goal(_ name: String, target: Decimal, saved: Decimal = 0, status: Goal.Status = .active) -> Goal {
        Goal(id: UUID(), name: name, target: target, saved: saved, deadline: nil, createdOn: now,
             status: status, completedOn: nil, history: [])
    }

    private func make() -> (SavedPresenter, FakeView, FakeInteractor, FakeRouter) {
        let view = FakeView(), interactor = FakeInteractor(), router = FakeRouter()
        let presenter = SavedPresenter(view: view, interactor: interactor, router: router, now: { [now] in now })
        return (presenter, view, interactor, router)
    }

    func testEmptyStateShowsInviteAndHidesPool() {
        let (presenter, view, _, _) = make()
        presenter.viewWillAppear()
        let model = view.models.last
        XCTAssertEqual(model?.showsInvite, true)
        XCTAssertNil(model?.pool)
        XCTAssertEqual(model?.goals.count, 0)
        XCTAssertNil(model?.finishedTitle)
    }

    func testNotNowHidesInviteForThirtyDays() {
        let (presenter, view, interactor, _) = make()
        presenter.tapNotNow()
        let days = Calendar.current.dateComponents([.day], from: now, to: interactor.inviteHiddenUntil ?? now).day
        XCTAssertEqual(days, 30)
        XCTAssertEqual(view.models.last?.showsInvite, false)
    }

    func testInviteReturnsAfterHiddenPeriod() {
        let (presenter, view, interactor, _) = make()
        interactor.inviteHiddenUntil = now.addingTimeInterval(-1)
        presenter.viewWillAppear()
        XCTAssertEqual(view.models.last?.showsInvite, true)
    }

    func testGoalsShowPoolAndFillsFirstOnlyOnFirstCard() {
        let (presenter, view, interactor, _) = make()
        interactor.activeGoals = [goal("Espresso", target: 490, saved: 245), goal("Japan", target: 2000)]
        interactor.pool = PendingPool(skipped: 489, unspent: 111, total: 600)
        presenter.viewWillAppear()
        let model = view.models.last
        XCTAssertEqual(model?.showsInvite, false)
        XCTAssertEqual(model?.pool?.amountText, "S$600")
        XCTAssertTrue(model?.pool?.detail.hasPrefix("S$489 skipped + S$111 unspent") ?? false)
        XCTAssertEqual(model?.goals.map(\.card.fillsFirst), [true, false])
        XCTAssertEqual(model?.goals.first?.card.savedText, "S$245")
        XCTAssertEqual(model?.goals.first?.card.progress, 0.5)
    }

    func testOnlyFinishedGoalsHidePoolAndInvite() {
        let (presenter, view, interactor, _) = make()
        interactor.finishedGoals = [goal("Old", target: 400, saved: 400, status: .archived)]
        presenter.viewWillAppear()
        let model = view.models.last
        XCTAssertNil(model?.pool)
        XCTAssertEqual(model?.showsInvite, false)
        XCTAssertEqual(model?.finishedTitle, "Finished goals (1)")
    }

    func testFinishedSectionStartsCollapsedAndToggles() {
        let (presenter, view, interactor, _) = make()
        interactor.finishedGoals = [goal("Old", target: 400, saved: 400, status: .archived)]
        presenter.viewWillAppear()
        XCTAssertEqual(view.models.last?.finished.count, 0)
        presenter.tapFinishedHeader()
        XCTAssertEqual(view.models.last?.finishedExpanded, true)
        XCTAssertEqual(view.models.last?.finished.count, 1)
    }

    func testKeptContentStaysAndTapsRoute() {
        let (presenter, view, interactor, router) = make()
        var skipped = Fixture.want("Keyboard", 189)
        skipped.status = .skipped
        interactor.wants = [skipped]
        presenter.viewWillAppear()
        XCTAssertEqual(view.models.last?.keptText, "S$189")
        XCTAssertEqual(view.models.last?.skippedText, "1 of 1")
        presenter.tapGoal(id: UUID())
        presenter.tapAddGoal()
        XCTAssertEqual(router.calls, ["detail", "editor"])
    }

    func testDataChangeRerenders() {
        let (presenter, view, _, _) = make()
        presenter.dataDidChange()
        XCTAssertEqual(view.models.count, 1)
    }
}
