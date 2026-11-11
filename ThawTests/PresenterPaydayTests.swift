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

    func testEmptyQueueShowsCountdownAndThawingRowsSoonestFirst() {
        let (presenter, view, interactor, _) = make()
        let now = interactor.now
        let payday = interactor.nextPayday
        let grinder = Want(id: UUID(), name: "Grinder", price: 420, reason: "", frozenOn: now,
                           progress: 0.2, status: .cooling, thawsAt: payday)
        let caseWant = want("Case", 24, thawsIn: 1, from: now)
        let later = want("Later", 50, thawsIn: 40, from: now)
        interactor.cooling = [grinder, caseWant, later]
        // Payday wants sit in the queue all month; they aren't ready until they thaw.
        interactor.queue = [grinder]
        presenter.viewWillAppear()

        let model = try! XCTUnwrap(view.models.last)
        XCTAssertEqual(model.heroValue, "14 days")
        XCTAssertEqual(model.heroCaption, "to \(Formatting.paydayDate(payday))")
        XCTAssertEqual(model.mood, .frozen)
        XCTAssertNil(model.reviewTitle)
        XCTAssertEqual(model.sections.map(\.title), ["Thawing this payday"])
        XCTAssertEqual(model.sections.first?.rows.map(\.id), [caseWant.id, grinder.id])
        XCTAssertEqual(model.sections.first?.detail, "S$444")
        XCTAssertEqual(model.budget, PaydayBudgetViewModel(text: "S$444 of S$300", fraction: 1.48, isOver: true))
        XCTAssertNil(model.emptyLine)
        XCTAssertTrue(model.heroSpoken.hasPrefix("14 days to payday, "))
        XCTAssertTrue(model.heroSpoken.hasSuffix(". 2 wants thaw then, S$444 of your S$300 fun money, S$144 over."))
    }

    func testCountdownCopy() {
        XCTAssertEqual(PaydayPresenter.daysText(0), "Today")
        XCTAssertEqual(PaydayPresenter.daysText(1), "1 day")
        XCTAssertEqual(PaydayPresenter.daysText(14), "14 days")
    }

    func testUnderBudgetSpokenHero() {
        let (presenter, view, interactor, _) = make()
        interactor.cooling = [want("Lamp", 120, thawsIn: 3, from: interactor.now)]
        presenter.viewWillAppear()
        let model = view.models.last
        XCTAssertEqual(model?.budget?.isOver, false)
        XCTAssertEqual(model?.budget?.text, "S$120 of S$300")
        XCTAssertEqual(model?.heroSpoken.hasSuffix(". 1 want thaws then, S$120 of your S$300 fun money."), true)
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
        XCTAssertEqual(model.heroCaption, "S$324 · S$300 fun money")
        XCTAssertEqual(model.mood, .thawed)
        XCTAssertEqual(model.reviewTitle, "Review")
        XCTAssertEqual(model.sections.map(\.title), ["Ready", "Thawing this payday"])
        XCTAssertEqual(model.sections.first?.rows.map(\.id), ready.map(\.id))
        XCTAssertEqual(model.sections.last?.rows.map(\.id), [thawing.id])

        presenter.tapReview()
        XCTAssertEqual(router.reviewed, [ready.map(\.id)])
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
