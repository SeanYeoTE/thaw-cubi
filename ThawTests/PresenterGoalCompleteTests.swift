import XCTest
@testable import Thaw

@MainActor
final class PresenterGoalCompleteTests: XCTestCase {
    private final class FakeView: GoalCompleteViewProtocol {
        var model: GoalCompleteViewModel?
        var feedback = 0
        func render(_ model: GoalCompleteViewModel) { self.model = model }
        func playSuccessFeedback() { feedback += 1 }
    }

    private final class FakeInteractor: GoalCompleteInteractorProtocol {
        var goal: Goal?
        var overflow: [GoalOverflow] = []
        var archived = 0
        func archive() { archived += 1 }
    }

    private final class FakeRouter: GoalCompleteRouterProtocol {
        var finished = 0
        func finish() { finished += 1 }
    }

    private func make(goal: Goal? = Goal(name: "Espresso setup", target: 900, saved: 900, createdOn: .now, status: .completed),
                      overflow: [GoalOverflow] = []) -> (GoalCompletePresenter, FakeView, FakeInteractor, FakeRouter) {
        let view = FakeView(), interactor = FakeInteractor(), router = FakeRouter()
        interactor.goal = goal
        interactor.overflow = overflow
        return (GoalCompletePresenter(view: view, interactor: interactor, router: router), view, interactor, router)
    }

    func testRendersCelebrationAndPlaysHaptic() {
        let (presenter, view, _, _) = make()
        presenter.viewDidLoad()
        XCTAssertEqual(view.model?.title, "Goal complete")
        XCTAssertEqual(view.model?.headline, "Espresso setup is fully funded")
        XCTAssertEqual(view.model?.amountText, "S$900 of S$900")
        XCTAssertEqual(view.feedback, 1)
    }

    func testBodyMentionsOverflowWhenAnotherGoalReceivedMoney() {
        let (presenter, view, _, _) = make(overflow: [GoalOverflow(goalName: "Japan trip", amount: 110)])
        presenter.viewDidLoad()
        XCTAssertEqual(view.model?.body.contains("The extra S$110 went to Japan trip."), true)
    }

    func testBodyOmitsOverflowWhenNone() {
        let (presenter, view, _, _) = make()
        presenter.viewDidLoad()
        XCTAssertEqual(view.model?.body.contains("extra"), false)
    }

    func testArchiveArchivesThenFinishes() {
        let (presenter, _, interactor, router) = make()
        presenter.viewDidLoad()
        presenter.tapArchive()
        XCTAssertEqual(interactor.archived, 1)
        XCTAssertEqual(router.finished, 1)
    }

    func testLaterFinishesWithoutArchiving() {
        let (presenter, _, interactor, router) = make()
        presenter.viewDidLoad()
        presenter.tapLater()
        XCTAssertEqual(interactor.archived, 0)
        XCTAssertEqual(router.finished, 1)
    }

    func testMissingGoalFinishesImmediately() {
        let (presenter, view, _, router) = make(goal: nil)
        presenter.viewDidLoad()
        XCTAssertNil(view.model)
        XCTAssertEqual(router.finished, 1)
    }
}
