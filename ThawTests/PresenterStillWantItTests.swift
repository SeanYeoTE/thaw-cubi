import XCTest
@testable import Thaw

@MainActor
final class PresenterStillWantItTests: XCTestCase {
    private final class FakeView: StillWantItViewProtocol {
        var models: [StillWantItViewModel] = []
        var momentLine: String?
        var momentCompletion: (() -> Void)?
        func render(_ model: StillWantItViewModel) { models.append(model) }
        func showSkipMoment(line: String, completion: @escaping () -> Void) {
            momentLine = line
            momentCompletion = completion
        }
    }

    private final class FakeInteractor: StillWantItInteractorProtocol {
        var wants: [Want]
        var budget: Decimal = 300
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
        XCTAssertEqual(view.models.last?.progressText, "Payday review · 1 of 2")
        XCTAssertEqual(view.models.last?.question, "Still want the keyboard?")
        XCTAssertEqual(view.models.last?.funText, "Fun money if you buy: S$111 of S$300 left")
        XCTAssertEqual(view.models.last?.keepTitle, "Skip and keep S$189")
    }

    func testBuyReducesFunMoneyForNextWantAndFinishesAfterLast() {
        var finished = 0
        let (presenter, view, interactor, router) = make(onFinish: { finished += 1 })
        presenter.viewDidLoad()
        presenter.tapBuy()
        XCTAssertEqual(view.models.last?.progressText, "Payday review · 2 of 2")
        XCTAssertEqual(view.models.last?.funText, "Fun money if you buy: S$42 of S$300 left")
        presenter.tapWait()
        XCTAssertEqual(interactor.log, ["buy Keyboard", "publish", "wait Shirt", "publish"])
        XCTAssertEqual(router.dismissed, 1)
        XCTAssertEqual(finished, 1)
    }

    func testSkipShowsMomentThenAdvances() {
        let (presenter, view, interactor, _) = make()
        presenter.viewDidLoad()
        presenter.tapSkip()
        XCTAssertEqual(view.momentLine, "S$189 stays with you.")
        XCTAssertEqual(interactor.log, ["skip Keyboard"])
        view.momentCompletion?()
        XCTAssertEqual(interactor.log, ["skip Keyboard", "publish"])
        XCTAssertEqual(view.models.last?.progressText, "Payday review · 2 of 2")
    }

    func testCloseDismissesWithoutFinishing() {
        var finished = 0
        let (presenter, _, _, router) = make(onFinish: { finished += 1 })
        presenter.tapClose()
        XCTAssertEqual(router.dismissed, 1)
        XCTAssertEqual(finished, 0)
    }
}
