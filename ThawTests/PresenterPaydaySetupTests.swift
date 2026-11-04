import XCTest
@testable import Thaw

@MainActor
final class PresenterPaydaySetupTests: XCTestCase {
    private final class FakeView: PaydaySetupViewProtocol {
        var content: PaydaySetupContent?
        var choices: [[SetupChoiceViewModel]] = []
        var details: [StepperViewModel?] = []
        var titles: [String] = []
        var savedShown = 0
        var feedback = 0
        func render(_ content: PaydaySetupContent) { self.content = content }
        func renderChoices(_ choices: [SetupChoiceViewModel]) { self.choices.append(choices) }
        func renderDetail(_ detail: StepperViewModel?) { details.append(detail) }
        func updateSaveTitle(_ title: String) { titles.append(title) }
        func showSavedConfirmation() { savedShown += 1 }
        func playSuccessFeedback() { feedback += 1 }
    }

    private final class FakeInteractor: PaydaySetupInteractorProtocol {
        var settings = PaydaySettings.default
        var saved: [PaydaySettings] = []
        func save(_ settings: PaydaySettings) { saved.append(settings) }
    }

    private final class FakeRouter: PaydaySetupRouterProtocol {
        var isOnboarding: Bool
        var finished = 0
        init(onboarding: Bool) { isOnboarding = onboarding }
        func finishOnboarding() { finished += 1 }
    }

    private func make(onboarding: Bool = false) -> (PaydaySetupPresenter, FakeView, FakeInteractor, FakeRouter) {
        let view = FakeView(), interactor = FakeInteractor(), router = FakeRouter(onboarding: onboarding)
        return (PaydaySetupPresenter(view: view, interactor: interactor, router: router), view, interactor, router)
    }

    func testInitialContentFromDefaults() {
        let (presenter, view, _, _) = make(onboarding: true)
        presenter.viewDidLoad()
        let content = view.content
        XCTAssertEqual(content?.isOnboarding, true)
        XCTAssertEqual(content?.choices.map(\.selected), [true, false, false, false])
        XCTAssertEqual(content?.choices.first?.hint, "On the 25th")
        XCTAssertEqual(content?.review.format(540), "9:00 am")
        XCTAssertEqual(content?.funMoney.format(300), "S$300")
        XCTAssertEqual(content?.timerLength.format(1), "1 day")
        XCTAssertTrue(content?.saveTitle.hasPrefix("Save · next payday ") == true)
    }

    func testSelectingRuleSwapsDetailAndSaves() {
        let (presenter, view, interactor, _) = make()
        presenter.viewDidLoad()
        presenter.selectChoice(at: 1)
        XCTAssertNil(view.details.last ?? nil)
        presenter.tapSave()
        XCTAssertEqual(interactor.saved.last?.rule, .lastWorkingDay)

        presenter.selectChoice(at: 3)
        XCTAssertEqual(view.details.last??.title, "Wait length")
        presenter.detailChanged(10)
        XCTAssertEqual(view.choices.last?.last?.hint, "Use a fixed wait instead (10 days)")
        presenter.tapSave()
        XCTAssertEqual(interactor.saved.last?.rule, .fixedWait(days: 10))
    }

    func testReselectingSameChoiceDoesNothing() {
        let (presenter, view, _, _) = make()
        presenter.viewDidLoad()
        presenter.selectChoice(at: 0)
        XCTAssertTrue(view.choices.isEmpty)
    }

    func testStepperValuesFlowIntoSavedSettings() {
        let (presenter, _, interactor, _) = make()
        presenter.viewDidLoad()
        presenter.reviewChanged(18 * 60 + 30)
        presenter.funMoneyChanged(450)
        presenter.timerThresholdChanged(40)
        presenter.timerLengthChanged(3)
        presenter.tapSave()
        let saved = interactor.saved.last
        XCTAssertEqual(saved?.reviewHour, 18)
        XCTAssertEqual(saved?.reviewMinute, 30)
        XCTAssertEqual(saved?.funMoney, 450)
        XCTAssertEqual(saved?.timerThreshold, 40)
        XCTAssertEqual(saved?.timerDays, 3)
    }

    func testSaveFinishesOnboardingOrConfirmsInSettings() {
        let (onboarding, onboardingView, _, onboardingRouter) = make(onboarding: true)
        onboarding.tapSave()
        XCTAssertEqual(onboardingRouter.finished, 1)
        XCTAssertEqual(onboardingView.savedShown, 0)

        let (settings, settingsView, _, settingsRouter) = make()
        settings.tapSave()
        XCTAssertEqual(settingsRouter.finished, 0)
        XCTAssertEqual(settingsView.savedShown, 1)
        XCTAssertEqual(settingsView.feedback, 1)
    }

    func testOrdinals() {
        XCTAssertEqual(PaydaySetupPresenter.ordinal(1), "1st")
        XCTAssertEqual(PaydaySetupPresenter.ordinal(12), "12th")
        XCTAssertEqual(PaydaySetupPresenter.ordinal(22), "22nd")
        XCTAssertEqual(PaydaySetupPresenter.ordinal(23), "23rd")
    }
}
