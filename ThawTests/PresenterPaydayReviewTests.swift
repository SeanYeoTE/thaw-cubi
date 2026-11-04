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
        var applied: [Set<UUID>] = []
        init(wants: [Want]) { self.wants = wants }
        func apply(keeping: Set<UUID>) { applied.append(keeping) }
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

    func testOnlyFirstFittingWantIsKeptByDefault() {
        let (presenter, view, _, _) = make()
        presenter.viewDidLoad()
        XCTAssertEqual(view.content?.rows.map(\.isKeeping), [true, false, false])
        XCTAssertEqual(view.summaries.last?.statusText, "S$189 kept · S$111 left")
        XCTAssertEqual(view.summaries.last?.ctaTitle, "Keep 1 · S$189")
    }

    func testFirstWantOverBudgetIsNotKept() {
        let (presenter, view, _, _) = make(wants: [grinder, shirt])
        presenter.viewDidLoad()
        XCTAssertEqual(view.content?.rows.map(\.isKeeping), [false, false])
        XCTAssertEqual(view.summaries.last?.ctaTitle, "Wait on all")
    }

    func testTogglingOverBudgetTurnsMeterWarm() {
        let (presenter, view, _, _) = make()
        presenter.viewDidLoad()
        presenter.setKeeping(id: grinder.id, keeping: true)
        XCTAssertEqual(view.summaries.last?.isOver, true)
        XCTAssertEqual(view.summaries.last?.fraction, 1)
        XCTAssertEqual(view.summaries.last?.statusText, "S$609 kept · S$309 over your fun money")
        presenter.setKeeping(id: grinder.id, keeping: false)
        XCTAssertEqual(view.summaries.last?.isOver, false)
    }

    func testCTAAppliesChoicesAndDismissesWithoutOnFinish() {
        let (presenter, view, interactor, router) = make()
        presenter.viewDidLoad()
        presenter.setKeeping(id: shirt.id, keeping: true)
        presenter.tapCTA()
        XCTAssertEqual(interactor.applied, [[keyboard.id, shirt.id]])
        XCTAssertEqual(view.feedback, 1)
        XCTAssertEqual(router.dismissed, 1)
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
        presenter.setKeeping(id: shirt.id, keeping: true)
        presenter.tapClose()
        XCTAssertEqual(view.discardShown, 1)
        XCTAssertEqual(router.dismissed, 1)
        presenter.confirmDiscard()
        XCTAssertEqual(router.dismissed, 2)
    }

    func testEmptyQueueRendersNoRows() {
        let (presenter, view, _, _) = make(wants: [])
        presenter.viewDidLoad()
        XCTAssertEqual(view.content?.rows.count, 0)
        XCTAssertEqual(view.summaries.last?.ctaTitle, "Wait on all")
    }
}
