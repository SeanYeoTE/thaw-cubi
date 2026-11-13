import XCTest
@testable import Thaw

@MainActor
final class PresenterPaydayReviewTests: XCTestCase {
    private final class FakeView: PaydayReviewViewProtocol {
        var content: PaydayReviewContent?
        var summaries: [PaydayReviewSummary] = []
        var discardShown = 0
        var feedback = 0
        var ctaEnabled: [Bool] = []
        func render(_ content: PaydayReviewContent) { self.content = content }
        func update(_ summary: PaydayReviewSummary, animated: Bool) { summaries.append(summary) }
        func showDiscardConfirmation() { discardShown += 1 }
        func playSuccessFeedback() { feedback += 1 }
        func setCTAEnabled(_ enabled: Bool) { ctaEnabled.append(enabled) }
    }

    private final class FakeInteractor: PaydayReviewInteractorProtocol {
        var wants: [Want]
        var budget: Decimal = 300
        var timerThreshold: Decimal = 30
        var applied: [[UUID: ReviewChoice]] = []
        init(wants: [Want]) { self.wants = wants }
        func apply(choices: [UUID: ReviewChoice]) { applied.append(choices) }
    }

    private final class FakeRouter: PaydayReviewRouterProtocol {
        var dismissed = 0
        func dismiss() { dismissed += 1 }
    }

    private static let start = Date(timeIntervalSince1970: 1_800_000_000)
    private let keyboard = want("Keyboard", 189, hour: 1)
    private let shirt = want("Shirt", 69, hour: 2)
    private let grinder = want("Grinder", 420, hour: 3)

    /// A want that thawed `hour` hours after a fixed start, so thaw order is explicit.
    private static func want(_ name: String, _ price: Decimal, hour: Double) -> Want {
        Want(id: UUID(), name: name, price: price, reason: "Because", frozenOn: start, progress: 1,
             status: .cooling, thawsAt: start.addingTimeInterval(3_600 * hour))
    }

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

    func testRowsFollowThawOrderNotQueueOrder() {
        let (presenter, view, _, _) = make(wants: [grinder, shirt, keyboard])
        presenter.viewDidLoad()
        XCTAssertEqual(view.content?.rows.map(\.id), [keyboard.id, shirt.id, grinder.id])
        XCTAssertEqual(view.content?.rows.map(\.choice), [.keep, .keep, .wait])
    }

    func testFirstWantOverBudgetWaits() {
        let big = Self.want("Big", 420, hour: 0)
        let (presenter, view, _, _) = make(wants: [big, shirt])
        presenter.viewDidLoad()
        XCTAssertEqual(view.content?.rows.map(\.choice), [.wait, .keep])
    }

    func testLaterCheaperWantStillDefaultsToKeepAfterOverflow() {
        // D5: best fit in thaw order. 189 fits, 420 doesn't, 69 still fits (S$42 left).
        let (presenter, view, _, _) = make(wants: [keyboard, Self.want("Grinder", 420, hour: 1.5), shirt])
        presenter.viewDidLoad()
        XCTAssertEqual(view.content?.rows.map(\.choice), [.keep, .wait, .keep])
        XCTAssertEqual(view.summaries.last?.statusText, "S$42 left")
    }

    func testQuickThawsHaveOwnGroupAndDontMoveTheMeter() {
        let quick = Self.want("Case", 24, hour: 0)
        let lamp = Self.want("Lamp", 280, hour: 1)
        let (presenter, view, interactor, _) = make(wants: [quick, lamp])
        presenter.viewDidLoad()
        XCTAssertEqual(view.content?.rows.map(\.id), [lamp.id])
        XCTAssertEqual(view.content?.rows.map(\.choice), [.keep])
        XCTAssertEqual(view.content?.quickTitle, "Quick thaws")
        XCTAssertEqual(view.content?.quickRows.map(\.id), [quick.id])
        XCTAssertEqual(view.content?.quickRows.map(\.choice), [.keep])
        XCTAssertEqual(view.summaries.last?.statusText, "S$20 left")
        XCTAssertEqual(view.summaries.last?.ctaTitle, "Done \u{00B7} keep 2")

        presenter.setChoice(id: quick.id, choice: .wait)
        XCTAssertEqual(view.summaries.last?.statusText, "S$20 left")
        presenter.setChoice(id: quick.id, choice: .letGo)
        XCTAssertEqual(view.summaries.last?.ctaTitle, "Done \u{00B7} keep 1, let go 1")
        presenter.tapCTA()
        XCTAssertEqual(interactor.applied, [[lamp.id: .keep, quick.id: .letGo]])
    }

    func testDoneTwiceAppliesOnce() {
        var finished = 0
        let (presenter, view, interactor, router) = make(onFinish: { finished += 1 })
        presenter.viewDidLoad()
        presenter.tapCTA()
        presenter.tapCTA()
        XCTAssertEqual(interactor.applied.count, 1)
        XCTAssertEqual(finished, 1)
        XCTAssertEqual(view.feedback, 1)
        XCTAssertEqual(view.ctaEnabled, [false])
        presenter.setChoice(id: shirt.id, choice: .letGo)
        presenter.tapClose()
        XCTAssertEqual(view.discardShown, 0)
        XCTAssertEqual(router.dismissed, 0)
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
