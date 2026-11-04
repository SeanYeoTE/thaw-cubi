import XCTest
@testable import Thaw

@MainActor
final class PresenterGoalDetailTests: XCTestCase {
    private final class FakeView: GoalDetailViewProtocol {
        var models: [GoalDetailViewModel] = []
        var deletePrompts: [(String, String)] = []
        func render(_ model: GoalDetailViewModel) { models.append(model) }
        func showDeleteConfirmation(title: String, message: String) { deletePrompts.append((title, message)) }
    }

    private final class FakeInteractor: GoalDetailInteractorProtocol {
        var goal: Goal?
        var firstFillingGoalId: UUID?
        var archived = 0
        var deleted = 0
        func archive() { archived += 1 }
        func delete() { deleted += 1 }
    }

    private final class FakeRouter: GoalDetailRouterProtocol {
        var editors = 0
        var pops = 0
        func showEditor() { editors += 1 }
        func pop() { pops += 1 }
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Singapore")!
        return calendar
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    private func sampleGoal() -> Goal {
        Goal(name: "Espresso setup", target: 900, saved: 410, deadline: date(2026, 12, 25), createdOn: date(2026, 9, 2),
             history: [
                GoalEvent(date: date(2026, 9, 20), kind: .contribution, amount: 100),
                GoalEvent(date: date(2026, 9, 30), kind: .contribution, amount: 150),
                GoalEvent(date: date(2026, 10, 31), kind: .contribution, amount: 160),
                GoalEvent(date: date(2026, 11, 26), kind: .extended, newDeadline: date(2026, 12, 25)),
             ])
    }

    private func make(goal: Goal?) -> (GoalDetailPresenter, FakeView, FakeInteractor, FakeRouter) {
        let view = FakeView(), interactor = FakeInteractor(), router = FakeRouter()
        interactor.goal = goal
        interactor.firstFillingGoalId = goal?.id
        let presenter = GoalDetailPresenter(view: view, interactor: interactor, router: router,
                                            calendar: calendar, now: { self.date(2026, 11, 27) })
        return (presenter, view, interactor, router)
    }

    func testHeaderFormatsProgressAndTags() {
        let (presenter, view, _, _) = make(goal: sampleGoal())
        presenter.viewDidLoad()
        let model = view.models.last
        XCTAssertEqual(model?.savedText, "S$410")
        XCTAssertEqual(model?.progressText, "of S$900 · 45%")
        XCTAssertEqual(model?.dueText, "Due Fri, 25 December · S$490 to go")
        XCTAssertEqual(model?.fillsFirst, true)
        XCTAssertEqual(model?.extended, true)
        XCTAssertEqual(model?.canEdit, true)
        XCTAssertEqual(model?.canArchive, true)
        XCTAssertEqual(model?.accessibilityLabel,
                       "Espresso setup, S$410 of S$900, 45 percent, due Fri, 25 December · S$490 to go, extended, fills first")
    }

    func testContributionsGroupedByMonthNewestFirst() {
        let (presenter, view, _, _) = make(goal: sampleGoal())
        presenter.viewDidLoad()
        XCTAssertEqual(view.models.last?.contributions,
                       [GoalContributionRow(month: "October", amount: "+S$160"),
                        GoalContributionRow(month: "September", amount: "+S$250")])
    }

    func testHistoryListsExtensionsAndCreation() {
        let (presenter, view, _, _) = make(goal: sampleGoal())
        presenter.viewDidLoad()
        let history = view.models.last?.history
        XCTAssertEqual(history?.map(\.title), ["Deadline extended", "Goal created"])
        XCTAssertEqual(history?.first?.date, "26 Nov")
        XCTAssertEqual(history?.last?.date, "2 Sep")
    }

    func testNoFillsFirstWhenAnotherGoalIsAhead() {
        let goal = sampleGoal()
        let (presenter, view, interactor, _) = make(goal: goal)
        interactor.firstFillingGoalId = UUID()
        presenter.viewDidLoad()
        XCTAssertEqual(view.models.last?.fillsFirst, false)
    }

    func testArchivedGoalCannotBeEditedOrArchivedAgain() {
        var goal = sampleGoal()
        goal.status = .archived
        let (presenter, view, _, _) = make(goal: goal)
        presenter.viewDidLoad()
        XCTAssertEqual(view.models.last?.canEdit, false)
        XCTAssertEqual(view.models.last?.canArchive, false)
        XCTAssertEqual(view.models.last?.fillsFirst, false)
    }

    func testTapEditOpensEditor() {
        let (presenter, _, _, router) = make(goal: sampleGoal())
        presenter.tapEdit()
        XCTAssertEqual(router.editors, 1)
    }

    func testArchiveArchivesAndLeaves() {
        let (presenter, view, interactor, router) = make(goal: sampleGoal())
        presenter.viewDidLoad()
        presenter.tapArchive()
        presenter.dataDidChange()
        XCTAssertEqual(interactor.archived, 1)
        XCTAssertEqual(router.pops, 1)
        XCTAssertEqual(view.models.count, 1)
    }

    func testDeleteRequiresConfirmation() {
        let (presenter, view, interactor, router) = make(goal: sampleGoal())
        presenter.viewDidLoad()
        presenter.tapDelete()
        XCTAssertEqual(view.deletePrompts.first?.0, "Delete Espresso setup?")
        XCTAssertEqual(interactor.deleted, 0)
        presenter.confirmDelete()
        XCTAssertEqual(interactor.deleted, 1)
        XCTAssertEqual(router.pops, 1)
    }

    func testDataChangeRerenders() {
        let (presenter, view, interactor, _) = make(goal: sampleGoal())
        presenter.viewDidLoad()
        interactor.goal?.saved = 600
        presenter.dataDidChange()
        XCTAssertEqual(view.models.count, 2)
        XCTAssertEqual(view.models.last?.savedText, "S$600")
    }

    func testMissingGoalPops() {
        let (presenter, view, _, router) = make(goal: nil)
        presenter.viewDidLoad()
        XCTAssertTrue(view.models.isEmpty)
        XCTAssertEqual(router.pops, 1)
    }
}
