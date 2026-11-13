import XCTest
@testable import Thaw

@MainActor
final class PresenterPaydayTests: XCTestCase {
    private final class FakeView: PaydayViewProtocol {
        var models: [PaydayViewModel] = []
        var successCount = 0
        func render(_ model: PaydayViewModel) { models.append(model) }
        func playSuccessFeedback() { successCount += 1 }
    }

    private final class FakeInteractor: PaydayInteractorProtocol {
        init() {}
        weak var output: PaydayInteractorOutput?
        var cooling: [Want] = []
        var queue: [Want] = []
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        lazy var nextPayday = now.addingTimeInterval(86_400 * 14)
        var funMoney: Decimal = 300
        var reminderCompletion: (() -> Void)?
        var reminderCalls = 0
        func snapshot() -> PaydaySnapshot {
            PaydaySnapshot(cooling: cooling, reviewQueue: queue,
                           payday: PaydaySchedule(nextPayday: nextPayday, funMoney: funMoney),
                           settings: .default, now: now)
        }
        func remindTonight(completion: @escaping () -> Void) {
            reminderCalls += 1
            reminderCompletion = completion
        }
    }

    private final class FakeRouter: PaydayRouterProtocol {
        var reviewed: [[UUID]] = []
        var details: [UUID] = []
        func showReview(wants: [Want]) { reviewed.append(wants.map(\.id)) }
        func showItemDetail(id: UUID) { details.append(id) }
    }

    private func make() -> (PaydayPresenter, FakeView, FakeInteractor, FakeRouter) {
        let view = FakeView(), interactor = FakeInteractor(), router = FakeRouter()
        return (PaydayPresenter(view: view, interactor: interactor, router: router), view, interactor, router)
    }

    private func want(_ name: String, _ price: Decimal, thawsIn days: Double, from now: Date) -> Want {
        Want(id: UUID(), name: name, price: price, reason: "Because", frozenOn: now.addingTimeInterval(-86_400),
             progress: 0.5, status: .cooling, thawsAt: now.addingTimeInterval(86_400 * days))
    }

    func testOverBudgetSplitsFitsAndOverByRunningTotalInThawOrder() {
        let (presenter, view, interactor, _) = make()
        let now = interactor.now
        let payday = interactor.nextPayday
        let grinder = Want(id: UUID(), name: "Grinder", price: 420, reason: "", frozenOn: now,
                           progress: 0.2, status: .cooling, thawsAt: payday)
        let lamp = want("Lamp", 282, thawsIn: 5, from: now)
        let desk = want("Desk", 400, thawsIn: 9, from: now)
        let later = want("Later", 50, thawsIn: 40, from: now)
        interactor.cooling = [grinder, desk, lamp, later]
        // Payday wants sit in the queue all month; they aren't ready until they thaw.
        interactor.queue = [grinder]
        presenter.viewWillAppear()

        let model = try! XCTUnwrap(view.models.last)
        XCTAssertEqual(model.heroValue, "14 days")
        XCTAssertEqual(model.heroCaption, "to \(Formatting.paydayDate(payday))")
        XCTAssertEqual(model.mood, .frozen)
        XCTAssertNil(model.reviewTitle)
        XCTAssertEqual(model.sections.map(\.title), ["Fits", "Over budget"])
        XCTAssertEqual(model.sections.map(\.detail), ["S$282", "S$820"])
        XCTAssertEqual(model.sections[0].rows.map(\.id), [lamp.id])
        XCTAssertEqual(model.sections[1].rows.map(\.id), [desk.id, grinder.id])
        let budget = try! XCTUnwrap(model.budget)
        XCTAssertEqual(budget.headline, "S$802 over")
        XCTAssertEqual(budget.caption, "S$1,102 thawing · S$300 fun money")
        XCTAssertTrue(budget.isOver)
        XCTAssertEqual(budget.fillFraction, 1.0 + (1_102.0 - 300) / 300, accuracy: 0.001)
        XCTAssertEqual(budget.markerFraction, 300.0 / 1_102, accuracy: 0.001)
        XCTAssertEqual(budget.spoken, "S$802 over. S$1,102 thawing against S$300 fun money.")
        XCTAssertTrue(model.heroSpoken.hasPrefix("14 days to payday, "))
        XCTAssertNil(model.emptyLine)
    }

    func testRowsCarryDaysLeftOnPaydayAndTimerWants() {
        let (presenter, view, interactor, _) = make()
        let now = interactor.now
        let lamp = want("Lamp", 120, thawsIn: 3, from: now)
        let quick = want("Case", 24, thawsIn: 1, from: now)
        interactor.cooling = [lamp, quick]
        presenter.viewWillAppear()
        let model = try! XCTUnwrap(view.models.last)
        XCTAssertEqual(model.sections.flatMap(\.rows).map(\.row.trailing), ["3 days", "1 day"])
    }

    func testUnderBudgetShowsOneSectionAndSpentLeft() {
        let (presenter, view, interactor, _) = make()
        let now = interactor.now
        let lamp = want("Lamp", 120, thawsIn: 3, from: now)
        let rug = want("Rug", 60, thawsIn: 2, from: now)
        interactor.cooling = [lamp, rug]
        presenter.viewWillAppear()
        let model = try! XCTUnwrap(view.models.last)
        XCTAssertEqual(model.budget?.headline, "S$120 left")
        XCTAssertEqual(model.budget?.caption, "S$180 thawing · S$300 fun money")
        XCTAssertEqual(model.budget?.isOver, false)
        XCTAssertEqual(model.budget?.fillFraction ?? 0, 0.6, accuracy: 0.001)
        XCTAssertEqual(model.budget?.markerFraction, 1)
        XCTAssertEqual(model.sections.map(\.title), ["Thawing this payday"])
        XCTAssertEqual(model.sections.first?.detail, "S$180")
        XCTAssertEqual(model.sections.first?.rows.map(\.id), [rug.id, lamp.id])
    }

    func testExactlyOnBudgetFits() {
        let (presenter, view, interactor, _) = make()
        let now = interactor.now
        interactor.cooling = [want("A", 100, thawsIn: 1, from: now), want("B", 200, thawsIn: 2, from: now)]
        presenter.viewWillAppear()
        let model = try! XCTUnwrap(view.models.last)
        XCTAssertEqual(model.budget?.headline, "S$0 left")
        XCTAssertEqual(model.budget?.isOver, false)
        XCTAssertEqual(model.sections.map(\.title), ["Thawing this payday"])
    }

    func testZeroFunMoneyEverythingIsOver() {
        let (presenter, view, interactor, _) = make()
        interactor.funMoney = 0
        interactor.cooling = [want("A", 100, thawsIn: 1, from: interactor.now)]
        presenter.viewWillAppear()
        let model = try! XCTUnwrap(view.models.last)
        XCTAssertEqual(model.budget?.headline, "S$100 over")
        XCTAssertEqual(model.budget?.fillFraction, 1)
        XCTAssertEqual(model.budget?.markerFraction, 0)
        XCTAssertEqual(model.sections.map(\.title), ["Over budget"])
    }

    func testQuickThawsAreExcludedFromPaydayTotalAndGetOwnSection() {
        let (presenter, view, interactor, _) = make()
        let now = interactor.now
        let lamp = want("Lamp", 120, thawsIn: 3, from: now)
        let quick = want("Case", 24, thawsIn: 1, from: now)
        interactor.cooling = [lamp, quick]
        presenter.viewWillAppear()
        let model = try! XCTUnwrap(view.models.last)
        XCTAssertEqual(model.budget?.headline, "S$180 left")
        XCTAssertEqual(model.sections.map(\.title), ["Thawing this payday", "Quick thaws"])
        XCTAssertEqual(model.sections.map(\.detail), ["S$120", "S$24"])
        XCTAssertEqual(model.sections.last?.rows.map(\.id), [quick.id])
        XCTAssertTrue(PaydayPresenter.isQuickThaw(quick, settings: .default))
        XCTAssertFalse(PaydayPresenter.isQuickThaw(lamp, settings: .default))
    }

    func testOnlyQuickThawsLeavesFullFunMoney() {
        let (presenter, view, interactor, _) = make()
        interactor.cooling = [want("Case", 24, thawsIn: 1, from: interactor.now)]
        presenter.viewWillAppear()
        let model = try! XCTUnwrap(view.models.last)
        XCTAssertEqual(model.budget?.headline, "S$300 left")
        XCTAssertEqual(model.sections.map(\.title), ["Quick thaws"])
    }

    func testCountdownCopy() {
        XCTAssertEqual(PaydayPresenter.daysText(0), "Today")
        XCTAssertEqual(PaydayPresenter.daysText(1), "1 day")
        XCTAssertEqual(PaydayPresenter.daysText(14), "14 days")
    }

    func testNothingCoolingShowsEmptyState() {
        let (presenter, view, _, _) = make()
        presenter.viewWillAppear()
        let model = view.models.last
        XCTAssertEqual(model?.emptyLine, "Nothing on ice.")
        XCTAssertEqual(model?.showsCubi, false)
        XCTAssertNil(model?.budget)
        XCTAssertEqual(model?.sections.isEmpty, true)
    }

    func testQueueOfThreeShowsReadyAndReviewRoutesThoseWants() {
        let (presenter, view, interactor, router) = make()
        let now = interactor.now
        let ready = [want("A", 100, thawsIn: -1, from: now), want("B", 200, thawsIn: -2, from: now),
                     want("C", 24, thawsIn: 0, from: now)]
        let thawing = want("D", 50, thawsIn: 3, from: now)
        interactor.cooling = ready + [thawing]
        interactor.queue = ready
        presenter.viewWillAppear()

        let model = try! XCTUnwrap(view.models.last)
        XCTAssertEqual(model.heroValue, "3 ready")
        XCTAssertEqual(model.heroCaption, "S$324 to decide")
        XCTAssertEqual(model.mood, .thawed)
        XCTAssertEqual(model.reviewTitle, "Review")
        // Ready budget counts payday wants only: A + B = S$300 fits exactly; the S$24 quick thaw is separate.
        XCTAssertEqual(model.budget?.headline, "S$0 left")
        XCTAssertEqual(model.budget?.caption, "S$300 ready · S$300 fun money")
        XCTAssertEqual(model.sections.map(\.title), ["Ready", "Quick thaws", "Thawing this payday"])
        // Thaw order: B thawed before A.
        XCTAssertEqual(model.sections.first?.rows.map(\.id), [ready[1].id, ready[0].id])
        XCTAssertEqual(model.sections[1].rows.map(\.id), [ready[2].id])
        XCTAssertEqual(model.sections.last?.rows.map(\.id), [thawing.id])

        presenter.tapReview()
        XCTAssertEqual(router.reviewed, [ready.map(\.id)])
    }

    func testReadyOverBudgetSplitsReadyRows() {
        let (presenter, view, interactor, _) = make()
        let now = interactor.now
        let a = want("A", 250, thawsIn: -1, from: now), b = want("B", 100, thawsIn: -1, from: now)
        interactor.cooling = [a, b]
        interactor.queue = [a, b]
        presenter.viewWillAppear()
        let model = try! XCTUnwrap(view.models.last)
        XCTAssertEqual(model.budget?.headline, "S$50 over")
        XCTAssertEqual(model.sections.map(\.title), ["Fits", "Over budget"])
        XCTAssertEqual(model.sections.map(\.detail), ["S$250", "S$100"])
    }

    func testOneReadyCopy() {
        let (presenter, view, interactor, _) = make()
        let one = want("A", 100, thawsIn: -1, from: interactor.now)
        interactor.cooling = [one]
        interactor.queue = [one]
        presenter.viewWillAppear()
        XCTAssertEqual(view.models.last?.heroValue, "1 ready")
    }

    func testReviewWithEmptyQueueDoesNothing() {
        let (presenter, _, interactor, router) = make()
        presenter.tapReview()
        interactor.queue = [want("Future", 200, thawsIn: 5, from: interactor.now)]
        presenter.tapReview()
        XCTAssertEqual(router.reviewed, [])
    }

    func testRemindTonightCallsInteractorAndShowsSuccess() {
        let (presenter, view, interactor, _) = make()
        let one = want("A", 100, thawsIn: -1, from: interactor.now)
        interactor.cooling = [one]
        interactor.queue = [one]
        presenter.viewWillAppear()
        XCTAssertEqual(view.models.last?.reminderState, .idle)

        presenter.tapRemindTonight()
        XCTAssertEqual(interactor.reminderCalls, 1)
        XCTAssertEqual(view.models.last?.reminderState, .busy)
        presenter.tapRemindTonight()
        XCTAssertEqual(interactor.reminderCalls, 1)

        interactor.reminderCompletion?()
        XCTAssertEqual(view.successCount, 1)
        XCTAssertEqual(view.models.last?.reminderState, .set)
        XCTAssertEqual(view.models.last?.reminderTitle, "Reminder set")
    }

    func testDataChangeRerenders() {
        let (presenter, view, interactor, _) = make()
        presenter.dataDidChange()
        XCTAssertEqual(view.models.count, 1)
        let one = want("A", 100, thawsIn: -1, from: interactor.now)
        interactor.cooling = [one]
        interactor.queue = [one]
        presenter.dataDidChange()
        XCTAssertEqual(view.models.count, 2)
        XCTAssertEqual(view.models.last?.heroValue, "1 ready")
    }

    func testRowTapRoutesToItemDetail() {
        let (presenter, _, _, router) = make()
        let id = UUID()
        presenter.tapWant(id: id)
        XCTAssertEqual(router.details, [id])
    }

    func testBadgeCountsOnlyThawedQueueWants() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let thawed = want("A", 24, thawsIn: -1, from: now)
        let payday = want("B", 200, thawsIn: 10, from: now)
        let ready = PaydayReadiness.ready(queue: [thawed, payday], now: now)
        XCTAssertEqual(ready.map(\.id), [thawed.id])
        XCTAssertEqual(PaydayReadiness.badgeValue(readyCount: ready.count), "1")
        XCTAssertNil(PaydayReadiness.badgeValue(readyCount: 0))
        XCTAssertEqual(PaydayReadiness.nextThaw(cooling: [thawed, payday], now: now), payday.thawsAt)
    }

    func testLaterCheaperReadyWantStillFitsAfterOverflow() {
        // D5: best fit in thaw order. 250 fits, 100 is over, 40 still fits.
        let (presenter, view, interactor, _) = make()
        let now = interactor.now
        let a = want("A", 250, thawsIn: -3, from: now), b = want("B", 100, thawsIn: -2, from: now)
        let c = want("C", 40, thawsIn: -1, from: now)
        interactor.cooling = [c, b, a]
        interactor.queue = [c, b, a]
        presenter.viewWillAppear()
        let model = try! XCTUnwrap(view.models.last)
        XCTAssertEqual(model.budget?.headline, "S$90 over")
        XCTAssertEqual(model.sections.map(\.title), ["Fits", "Over budget"])
        XCTAssertEqual(model.sections[0].rows.map(\.id), [a.id, c.id])
        XCTAssertEqual(model.sections[1].rows.map(\.id), [b.id])
    }

    // MARK: - Same budget on the Payday tab and in the review

    private final class FakeReviewView: PaydayReviewViewProtocol {
        var summaries: [PaydayReviewSummary] = []
        func render(_ content: PaydayReviewContent) {}
        func update(_ summary: PaydayReviewSummary, animated: Bool) { summaries.append(summary) }
        func showDiscardConfirmation() {}
        func playSuccessFeedback() {}
        func setCTAEnabled(_ enabled: Bool) {}
    }

    private final class FakeReviewInteractor: PaydayReviewInteractorProtocol {
        let wants: [Want]
        let budget: Decimal
        let timerThreshold = PaydaySettings.default.timerThreshold
        init(wants: [Want], budget: Decimal) { self.wants = wants; self.budget = budget }
        func apply(choices: [UUID: ReviewChoice]) {}
    }

    private final class FakeReviewRouter: PaydayReviewRouterProtocol {
        func dismiss() {}
    }

    func testPaydayTabAndReviewAgreeOnLeftWithAQuickThaw() {
        // S$300 fun money; a S$24 quick thaw and a S$280 payday want are ready. Both screens say S$20 left.
        let (presenter, view, interactor, router) = make()
        let now = interactor.now
        let quick = want("Case", 24, thawsIn: -2, from: now)
        let lamp = want("Lamp", 280, thawsIn: -1, from: now)
        interactor.cooling = [quick, lamp]
        interactor.queue = [quick, lamp]
        presenter.viewWillAppear()
        XCTAssertEqual(view.models.last?.budget?.headline, "S$20 left")

        presenter.tapReview()
        let routed = router.reviewed.last ?? []
        let reviewWants = interactor.queue.filter { routed.contains($0.id) }
        let reviewView = FakeReviewView()
        let review = PaydayReviewPresenter(view: reviewView,
                                           interactor: FakeReviewInteractor(wants: reviewWants, budget: interactor.funMoney),
                                           router: FakeReviewRouter(), onFinish: nil)
        review.viewDidLoad()
        XCTAssertEqual(reviewView.summaries.last?.statusText, "S$20 left")
        XCTAssertEqual(reviewView.summaries.last?.isOver, false)
    }
}

final class FunMoneyPlanTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func want(_ name: String, _ price: Decimal, day: Double) -> Want {
        Want(id: UUID(), name: name, price: price, reason: "", frozenOn: start, progress: 1,
             status: .cooling, thawsAt: start.addingTimeInterval(86_400 * day))
    }

    private func plan(_ wants: [Want], _ funMoney: Decimal) -> FunMoneyPlan {
        FunMoneyPlan.make(wants: wants, funMoney: funMoney, timerThreshold: 30)
    }

    func testExactlyOnBudgetFitsWithNothingLeft() {
        let plan = plan([want("A", 100, day: 1), want("B", 200, day: 2)], 300)
        XCTAssertEqual(plan.payday.map(\.fits), [true, true])
        XCTAssertFalse(plan.isOver)
        XCTAssertEqual(plan.left, 0)
        XCTAssertEqual(plan.overBy, 0)
        XCTAssertEqual(plan.paydayTotal, 300)
        XCTAssertEqual(plan.fitsTotal, 300)
    }

    func testZeroFunMoneyEverythingIsOver() {
        let plan = plan([want("A", 100, day: 1), want("B", 50, day: 2)], 0)
        XCTAssertEqual(plan.payday.map(\.fits), [false, false])
        XCTAssertTrue(plan.isOver)
        XCTAssertEqual(plan.overBy, 150)
        XCTAssertEqual(plan.left, 0)
        XCTAssertEqual(plan.fitsTotal, 0)
    }

    func testOnlyQuickThawsSpendNothing() {
        let a = want("A", 24, day: 2), b = want("B", 12, day: 1)
        let plan = plan([a, b], 300)
        XCTAssertTrue(plan.payday.isEmpty)
        XCTAssertEqual(plan.quickThaws.map(\.id), [b.id, a.id])
        XCTAssertEqual(plan.quickTotal, 36)
        XCTAssertEqual(plan.paydayTotal, 0)
        XCTAssertEqual(plan.left, 300)
        XCTAssertFalse(plan.isOver)
    }

    func testCheaperWantAfterOverflowStillFits() {
        let a = want("A", 189, day: 1), b = want("B", 420, day: 2), c = want("C", 69, day: 3)
        let plan = plan([a, b, c], 300)
        XCTAssertEqual(plan.payday.map(\.fits), [true, false, true])
        XCTAssertEqual(plan.fits.map(\.id), [a.id, c.id])
        XCTAssertEqual(plan.over.map(\.id), [b.id])
        XCTAssertEqual(plan.fitsTotal, 258)
        XCTAssertEqual(plan.overBy, 378)
    }

    func testMixedOrderIsSortedByThawDate() {
        let late = want("Late", 200, day: 5), early = want("Early", 150, day: 1)
        let quick = want("Quick", 20, day: 0), middle = want("Middle", 100, day: 3)
        let plan = plan([late, quick, middle, early], 300)
        XCTAssertEqual(plan.payday.map(\.want.id), [early.id, middle.id, late.id])
        XCTAssertEqual(plan.payday.map(\.fits), [true, true, false])
        XCTAssertEqual(plan.ordered.map(\.id), [early.id, middle.id, late.id, quick.id])
    }

    func testSummaryCountsOnlyKeptPaydayWants() {
        let quick = want("Quick", 20, day: 0), lamp = want("Lamp", 280, day: 1)
        let plan = plan([quick, lamp], 300)
        let summary = plan.summary(keeping: [quick.id, lamp.id])
        XCTAssertEqual(summary.kept, 280)
        XCTAssertEqual(summary.remaining, 20)
    }

}
