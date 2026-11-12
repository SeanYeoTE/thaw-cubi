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
        XCTAssertEqual(model.sections.first?.rows.map(\.id), [ready[0].id, ready[1].id])
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
}
