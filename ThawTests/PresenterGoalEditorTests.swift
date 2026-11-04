import XCTest
@testable import Thaw

@MainActor
final class PresenterGoalEditorTests: XCTestCase {
    private final class FakeView: GoalEditorViewProtocol {
        var model: GoalEditorViewModel?
        var saveEnabled: [Bool] = []
        var hints: [(String, Bool)] = []
        var modal: [Bool] = []
        var errors: [String] = []
        var discards = 0
        func render(_ model: GoalEditorViewModel) { self.model = model }
        func setSaveEnabled(_ isEnabled: Bool) { saveEnabled.append(isEnabled) }
        func setHint(_ text: String, isWarning: Bool) { hints.append((text, isWarning)) }
        func setModalInPresentation(_ isModal: Bool) { modal.append(isModal) }
        func showError(_ message: String) { errors.append(message) }
        func showDiscardConfirmation() { discards += 1 }
    }

    private final class FakeInteractor: GoalEditorInteractorProtocol {
        var goal: Goal?
        var funMoney: Decimal = 300
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        var suggestedDeadline = Date(timeIntervalSince1970: 1_802_000_000)
        var saved: [(String, Decimal, Date?)] = []
        var failure: GoalError?
        func save(name: String, target: Decimal, deadline: Date?) throws {
            if let failure { throw failure }
            saved.append((name, target, deadline))
        }
    }

    private final class FakeRouter: GoalEditorRouterProtocol {
        var finished = 0
        func finish() { finished += 1 }
    }

    private func make(goal: Goal? = nil) -> (GoalEditorPresenter, FakeView, FakeInteractor, FakeRouter) {
        let view = FakeView(), interactor = FakeInteractor(), router = FakeRouter()
        interactor.goal = goal
        let presenter = GoalEditorPresenter(view: view, interactor: interactor, router: router)
        return (presenter, view, interactor, router)
    }

    private func input(name: String = "Espresso", target: String = "900", deadline: Bool = false) -> GoalEditorInput {
        GoalEditorInput(name: name, target: target, hasDeadline: deadline, deadline: Date(timeIntervalSince1970: 1_802_000_000))
    }

    func testAddModeStartsEmptyAndSaveDisabled() {
        let (presenter, view, _, _) = make()
        presenter.viewDidLoad()
        XCTAssertEqual(view.model?.title, "New goal")
        XCTAssertEqual(view.model?.input.name, "")
        XCTAssertEqual(view.saveEnabled.last, false)
        XCTAssertEqual(view.modal.last, false)
        XCTAssertEqual(view.hints.last?.0, "Goals are for wants over S$300, your monthly fun money.")
    }

    func testEditModePrefillsFromGoal() {
        let goal = Goal(name: "Japan", target: 2000, deadline: Date(timeIntervalSince1970: 1_810_000_000), createdOn: .now)
        let (presenter, view, _, _) = make(goal: goal)
        presenter.viewDidLoad()
        XCTAssertEqual(view.model?.title, "Edit goal")
        XCTAssertEqual(view.model?.input.name, "Japan")
        XCTAssertEqual(view.model?.input.target, "2000")
        XCTAssertEqual(view.model?.input.hasDeadline, true)
        XCTAssertEqual(view.saveEnabled.last, true)
    }

    func testSaveEnabledOnlyWhenTargetExceedsFunMoney() {
        let (presenter, view, _, _) = make()
        presenter.viewDidLoad()
        presenter.inputChanged(input(target: "300"))
        XCTAssertEqual(view.saveEnabled.last, false)
        XCTAssertEqual(view.hints.last?.1, true)
        presenter.inputChanged(input(target: "S$1,100"))
        XCTAssertEqual(view.saveEnabled.last, true)
        XCTAssertEqual(view.hints.last?.1, false)
        presenter.inputChanged(input(name: "  ", target: "900"))
        XCTAssertEqual(view.saveEnabled.last, false)
    }

    func testEmptyTargetShowsNoWarning() {
        let (presenter, view, _, _) = make()
        presenter.viewDidLoad()
        presenter.inputChanged(input(target: ""))
        XCTAssertEqual(view.hints.last?.1, false)
    }

    func testSaveCreatesGoalWithOptionalDeadline() {
        let (presenter, _, interactor, router) = make()
        presenter.viewDidLoad()
        presenter.tapSave(input(name: "  Espresso setup ", target: "900"))
        XCTAssertEqual(interactor.saved.first?.0, "Espresso setup")
        XCTAssertEqual(interactor.saved.first?.1, 900)
        XCTAssertNil(interactor.saved.first?.2)
        XCTAssertEqual(router.finished, 1)

        let (second, _, interactor2, _) = make()
        second.tapSave(input(deadline: true))
        XCTAssertNotNil(interactor2.saved.first?.2)
    }

    func testSaveRejectsLowTargetAndEmptyName() {
        let (presenter, view, interactor, router) = make()
        presenter.tapSave(input(target: "250"))
        presenter.tapSave(input(name: " ", target: "900"))
        XCTAssertEqual(view.errors, ["Set a target over S$300.", "Add a name for the goal."])
        XCTAssertTrue(interactor.saved.isEmpty)
        XCTAssertEqual(router.finished, 0)
    }

    func testStoreErrorIsShownAndEditorStaysOpen() {
        let (presenter, view, interactor, router) = make()
        interactor.failure = .targetTooLow
        presenter.tapSave(input())
        XCTAssertEqual(view.errors.count, 1)
        XCTAssertEqual(router.finished, 0)
    }

    func testCloseWithoutEditsDismissesWithoutConfirmation() {
        let (presenter, view, _, router) = make()
        presenter.viewDidLoad()
        presenter.tapClose(input(name: "", target: ""))
        XCTAssertEqual(view.discards, 0)
        XCTAssertEqual(router.finished, 1)
    }

    func testCloseAfterEditsAsksThenDiscards() {
        let (presenter, view, _, router) = make()
        presenter.viewDidLoad()
        presenter.inputChanged(input(name: "Espresso", target: ""))
        XCTAssertEqual(view.modal.last, true)
        presenter.tapClose(input(name: "Espresso", target: ""))
        XCTAssertEqual(view.discards, 1)
        XCTAssertEqual(router.finished, 0)
        presenter.confirmDiscard()
        XCTAssertEqual(router.finished, 1)
    }

    func testSwipeDismissAlwaysConfirms() {
        let (presenter, view, _, router) = make()
        presenter.didAttemptDismiss(input())
        XCTAssertEqual(view.discards, 1)
        XCTAssertEqual(router.finished, 0)
    }

    func testEditingBackToOriginalIsNotAnEdit() {
        let goal = Goal(name: "Japan", target: 2000, createdOn: .now)
        let (presenter, view, _, router) = make(goal: goal)
        presenter.viewDidLoad()
        presenter.inputChanged(input(name: "Japan", target: "2000"))
        XCTAssertEqual(view.modal.last, false)
        presenter.tapClose(input(name: "Japan", target: "2000"))
        XCTAssertEqual(router.finished, 1)
    }

    func testDeadlineDateIgnoredWhileSwitchOff() {
        let (presenter, view, _, _) = make()
        presenter.viewDidLoad()
        var changed = input(name: "", target: "")
        changed.deadline = Date(timeIntervalSince1970: 1_900_000_000)
        presenter.inputChanged(changed)
        XCTAssertEqual(view.modal.last, false)
    }

    func testModalLiftedAfterSave() {
        let (presenter, view, _, _) = make()
        presenter.viewDidLoad()
        presenter.inputChanged(input())
        presenter.tapSave(input())
        XCTAssertEqual(view.modal.last, false)
    }
}
