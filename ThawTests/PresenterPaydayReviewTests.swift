import XCTest
@testable import Thaw

@MainActor
final class PresenterPaydayReviewTests: XCTestCase {
    private final class FakeView: PaydayReviewViewProtocol {
        var content: PaydayReviewContent?
        var summaries: [PaydayReviewSummary] = []
        var discardShown = 0
        var feedback = 0
        func render(_ content: PaydayReviewContent) { self.content = content }
        func update(_ summary: PaydayReviewSummary, animated: Bool) { summaries.append(summary) }
        func showDiscardConfirmation() { discardShown += 1 }
        func playSuccessFeedback() { feedback += 1 }
    }

    private final class FakeInteractor: PaydayReviewInteractorProtocol {
        var wants: [Want]
        var budget: Decimal = 300
        var applied: [[UUID: ReviewChoice]] = []
        init(wants: [Want]) { self.wants = wants }
        func apply(choices: [UUID: ReviewChoice]) { applied.append(choices) }
    }

    private final class FakeRouter: PaydayReviewRouterProtocol {
        var dismissed = 0
        func dismiss() { dismissed += 1 }
    }

    private let keyboard = Fixture.want("Keyboard", 189)
    private let shirt = Fixture.want("Shirt", 69)
    private let grinder = Fixture.want("Grinder", 420)

    private func make(wants: [Want]? = nil, onFinish: (() -> Void)? = nil)
        -> (PaydayReviewPresenter, FakeView, FakeInteractor, FakeRouter) {
        let view = FakeView(), interactor = FakeInteractor(wants: wants ?? [keyboard, shirt, grinder]), router = FakeRouter()
        let presenter = PaydayReviewPresenter(view: view, interactor: interactor, router: router, onFinish: onFinish)
        return (presenter, view, interactor, router)
    }

    func testWantsAreKeptWhileTheyFitOtherwiseWait() {
        let (presenter, view, _, _) = make()
        presenter.viewDidLoad()
        XCTAssertEqual(view.content?.rows.map(\.choice), [.keep, .keep, .wait])
        XCTAssertEqual(view.summaries.last?.statusText, "S$42 left")
        XCTAssertEqual(view.summaries.last?.ctaTitle, "Done \u{00B7} keep 2")
    }

    func testFirstWantOverBudgetWaits() {
        let (presenter, view, _, _) = make(wants: [grinder, shirt])
        presenter.viewDidLoad()
        XCTAssertEqual(view.content?.rows.map(\.choice), [.wait, .keep])
    }

    func testAllOverBudgetWaitsOnAll() {
        let (presenter, view, _, _) = make(wants: [grinder])
        presenter.viewDidLoad()
        XCTAssertEqual(view.content?.rows.map(\.choice), [.wait])
        XCTAssertEqual(view.summaries.last?.ctaTitle, "Wait on all")
    }

    func testKeepingOverBudgetTurnsMeterWarm() {
        let (presenter, view, _, _) = make()
        presenter.viewDidLoad()
        presenter.setChoice(id: grinder.id, choice: .keep)
        XCTAssertEqual(view.summaries.last?.isOver, true)
        XCTAssertEqual(view.summaries.last?.fraction, 1)
        XCTAssertEqual(view.summaries.last?.statusText, "S$378 over")
        presenter.setChoice(id: grinder.id, choice: .wait)
        XCTAssertEqual(view.summaries.last?.isOver, false)
    }

    func testLetGoSpendsNothingAndShowsInCTA() {
        let (presenter, view, _, _) = make()
        presenter.viewDidLoad()
        presenter.setChoice(id: shirt.id, choice: .letGo)
        XCTAssertEqual(view.summaries.last?.statusText, "S$111 left")
        XCTAssertEqual(view.summaries.last?.ctaTitle, "Done \u{00B7} keep 1, let go 1")
        presenter.setChoice(id: keyboard.id, choice: .wait)
        XCTAssertEqual(view.summaries.last?.statusText, "S$300 left")
        XCTAssertEqual(view.summaries.last?.ctaTitle, "Done \u{00B7} let go 1")
    }

    func testCTAAppliesEveryChoiceAndDismissesWithoutOnFinish() {
        let (presenter, view, interactor, router) = make()
        presenter.viewDidLoad()
        presenter.setChoice(id: shirt.id, choice: .letGo)
        presenter.tapCTA()
        XCTAssertEqual(interactor.applied, [[keyboard.id: .keep, shirt.id: .letGo, grinder.id: .wait]])
        XCTAssertEqual(view.feedback, 1)
        XCTAssertEqual(router.dismissed, 1)
    }

    func testWaitOnAllAppliesWaitToEveryWant() {
        let (presenter, _, interactor, _) = make()
        presenter.viewDidLoad()
        presenter.setChoice(id: keyboard.id, choice: .wait)
        presenter.setChoice(id: shirt.id, choice: .wait)
        presenter.tapCTA()
        XCTAssertEqual(interactor.applied.last?.values.allSatisfy { $0 == .wait }, true)
    }

    func testOnFinishReplacesDismiss() {
        var finished = 0
        let (presenter, _, _, router) = make(onFinish: { finished += 1 })
        presenter.viewDidLoad()
        presenter.tapCTA()
        XCTAssertEqual(finished, 1)
        XCTAssertEqual(router.dismissed, 0)
    }

    func testCloseConfirmsOnlyWhenChoicesChanged() {
        let (presenter, view, _, router) = make()
        presenter.viewDidLoad()
        presenter.tapClose()
        XCTAssertEqual(router.dismissed, 1)
        XCTAssertEqual(view.discardShown, 0)
        presenter.setChoice(id: shirt.id, choice: .letGo)
        presenter.tapClose()
        XCTAssertEqual(view.discardShown, 1)
        XCTAssertEqual(router.dismissed, 1)
        presenter.confirmDiscard()
        XCTAssertEqual(router.dismissed, 2)
    }

    func testRevertingAPickDoesNotAskToDiscard() {
        let (presenter, view, _, router) = make()
        presenter.viewDidLoad()
        presenter.setChoice(id: shirt.id, choice: .letGo)
        presenter.setChoice(id: shirt.id, choice: .keep)
        presenter.tapClose()
        XCTAssertEqual(view.discardShown, 0)
        XCTAssertEqual(router.dismissed, 1)
    }

    func testEmptyQueueRendersNoRows() {
        let (presenter, view, _, _) = make(wants: [])
        presenter.viewDidLoad()
        XCTAssertEqual(view.content?.rows.count, 0)
        XCTAssertEqual(view.summaries.last?.ctaTitle, "Wait on all")
    }
}
