import XCTest
@testable import Thaw

@MainActor
final class PresenterStillWantItTests: XCTestCase {
    private final class FakeView: StillWantItViewProtocol {
        var models: [StillWantItViewModel] = []
        var momentLine: String?
        var momentCompletion: (() -> Void)?
        var actionsEnabled: [Bool] = []
        func render(_ model: StillWantItViewModel) { models.append(model) }
        func showSkipMoment(line: String, completion: @escaping () -> Void) {
            momentLine = line
            momentCompletion = completion
        }
        func setActionsEnabled(_ enabled: Bool) { actionsEnabled.append(enabled) }
    }

    private final class FakeInteractor: StillWantItInteractorProtocol {
        var wants: [Want]
        var budget: Decimal = 300
        var timerThreshold: Decimal = 30
        var log: [String] = []
        init(wants: [Want]) { self.wants = wants }
        func skip(_ want: Want) { log.append("skip \(want.name)") }
        func buy(_ want: Want) { log.append("buy \(want.name)") }
        func wait(_ want: Want) { log.append("wait \(want.name)") }
        func publishChange() { log.append("publish") }
    }

    private final class FakeRouter: StillWantItRouterProtocol {
        var dismissed = 0
        func dismiss(completion: (() -> Void)?) {
            dismissed += 1
            completion?()
        }
    }

    private let first = Fixture.want("Keyboard", 189)
    private let second = Fixture.want("Shirt", 69)

    private func make(onFinish: (() -> Void)? = nil) -> (StillWantItPresenter, FakeView, FakeInteractor, FakeRouter) {
        let view = FakeView(), interactor = FakeInteractor(wants: [first, second]), router = FakeRouter()
        return (StillWantItPresenter(view: view, interactor: interactor, router: router, onFinish: onFinish),
                view, interactor, router)
    }

    func testRendersFirstWant() {
        let (presenter, view, _, _) = make()
        presenter.viewDidLoad()
        let model = view.models.last
        XCTAssertEqual(model?.progressText, "1 of 2")
        XCTAssertEqual(model?.name, "Keyboard")
        XCTAssertEqual(model?.priceText, "S$189")
        XCTAssertEqual(model?.meterText, "S$111 left if you buy")
        XCTAssertEqual(model?.meterIsOver, false)
        XCTAssertEqual(model?.letGoTitle, "Let go \u{00B7} save S$189")
        XCTAssertEqual(model?.buyTitle, "Buy it")
        XCTAssertEqual(model?.waitTitle, "Wait a payday")
    }

    func testBuyReducesFunMoneyForNextWantAndFinishesAfterLast() {
        var finished = 0
        let (presenter, view, interactor, router) = make(onFinish: { finished += 1 })
        presenter.viewDidLoad()
        presenter.tapBuy()
        XCTAssertEqual(view.models.last?.progressText, "2 of 2")
        XCTAssertEqual(view.models.last?.meterText, "S$42 left if you buy")
        presenter.tapWait()
        XCTAssertEqual(interactor.log, ["buy Keyboard", "publish", "wait Shirt", "publish"])
        XCTAssertEqual(router.dismissed, 1)
        XCTAssertEqual(finished, 1)
    }

    func testMeterShowsOverWhenBuyingExceedsFunMoney() {
        let (presenter, view, interactor, _) = make()
        interactor.budget = 200
        presenter.viewDidLoad()
        presenter.tapBuy()
        XCTAssertEqual(view.models.last?.meterText, "S$58 over if you buy")
        XCTAssertEqual(view.models.last?.meterIsOver, true)
        XCTAssertEqual(view.models.last?.meterFraction, 1)
    }

    func testLetGoShowsMomentThenAdvancesAndSpendsNothing() {
        let (presenter, view, interactor, _) = make()
        presenter.viewDidLoad()
        presenter.tapLetGo()
        XCTAssertEqual(view.momentLine, "S$189 stays with you.")
        // Published before the moment completes, so other tabs update straight away.
        XCTAssertEqual(interactor.log, ["skip Keyboard", "publish"])
        XCTAssertEqual(view.actionsEnabled, [false])
        view.momentCompletion?()
        XCTAssertEqual(interactor.log, ["skip Keyboard", "publish"])
        XCTAssertEqual(view.actionsEnabled, [false, true])
        XCTAssertEqual(view.models.last?.progressText, "2 of 2")
        XCTAssertEqual(view.models.last?.meterText, "S$231 left if you buy")
    }

    func testTapsDuringLetGoMomentAreIgnored() {
        let (presenter, _, interactor, _) = make()
        presenter.viewDidLoad()
        presenter.tapLetGo()
        presenter.tapBuy()
        presenter.tapWait()
        presenter.tapLetGo()
        XCTAssertEqual(interactor.log, ["skip Keyboard", "publish"])
    }

    func testTappingAgainAfterLastWantIsDecidedDoesNothing() {
        var finished = 0
        let view = FakeView(), interactor = FakeInteractor(wants: [first]), router = FakeRouter()
        let presenter = StillWantItPresenter(view: view, interactor: interactor, router: router,
                                             onFinish: { finished += 1 })
        presenter.viewDidLoad()
        presenter.tapBuy()
        presenter.tapBuy()
        presenter.tapWait()
        presenter.tapLetGo()
        presenter.tapClose()
        XCTAssertEqual(interactor.log, ["buy Keyboard", "publish"])
        XCTAssertEqual(router.dismissed, 1)
        XCTAssertEqual(finished, 1)
        XCTAssertEqual(view.actionsEnabled, [false])
    }

    func testWaitTwiceOnLastWantWaitsOnce() {
        let view = FakeView(), interactor = FakeInteractor(wants: [first]), router = FakeRouter()
        let presenter = StillWantItPresenter(view: view, interactor: interactor, router: router, onFinish: nil)
        presenter.viewDidLoad()
        presenter.tapWait()
        presenter.tapWait()
        XCTAssertEqual(interactor.log, ["wait Keyboard", "publish"])
        XCTAssertEqual(router.dismissed, 1)
    }

    func testQuickThawDoesNotCountAgainstFunMoney() {
        let quick = Fixture.want("Case", 24)
        let view = FakeView(), interactor = FakeInteractor(wants: [first, quick]), router = FakeRouter()
        let presenter = StillWantItPresenter(view: view, interactor: interactor, router: router, onFinish: nil)
        presenter.viewDidLoad()
        presenter.tapBuy()
        XCTAssertEqual(view.models.last?.name, "Case")
        XCTAssertEqual(view.models.last?.meterText, "S$111 left if you buy")
    }

    func testSingleWantHidesProgress() {
        let view = FakeView(), interactor = FakeInteractor(wants: [first]), router = FakeRouter()
        let presenter = StillWantItPresenter(view: view, interactor: interactor, router: router, onFinish: nil)
        presenter.viewDidLoad()
        XCTAssertEqual(view.models.last?.progressText, "")
    }

    func testCloseDismissesWithoutFinishing() {
        var finished = 0
        let (presenter, _, _, router) = make(onFinish: { finished += 1 })
        presenter.tapClose()
        XCTAssertEqual(router.dismissed, 1)
        XCTAssertEqual(finished, 0)
    }
}
