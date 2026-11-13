import XCTest
@testable import Thaw

@MainActor
final class PresenterPaydaySetupTests: XCTestCase {
    private final class FakeInteractor: PaydaySetupInteractorProtocol {
        init() {}
        weak var output: PaydaySetupInteractorOutput?
        var settings = PaydaySettings.default
        var saved: [PaydaySettings] = []
        var permissions: [Bool] = []
        func save(_ settings: PaydaySettings, requestingPermission: Bool) {
            self.settings = settings
            saved.append(settings)
            permissions.append(requestingPermission)
        }
    }

    // MARK: Onboarding

    private final class FakeOnboardingView: PaydaySetupViewProtocol {
        var content: PaydaySetupContent?
        var choices: [[SetupChoiceViewModel]] = []
        var details: [StepperViewModel?] = []
        var titles: [String] = []
        var feedback = 0
        func render(_ content: PaydaySetupContent) { self.content = content }
        func renderChoices(_ choices: [SetupChoiceViewModel]) { self.choices.append(choices) }
        func renderDetail(_ detail: StepperViewModel?) { details.append(detail) }
        func updateContinueTitle(_ title: String) { titles.append(title) }
        func playSuccessFeedback() { feedback += 1 }
    }

    private final class FakeOnboardingRouter: PaydaySetupRouterProtocol {
        var finished = 0
        func finishOnboarding() { finished += 1 }
    }

    private func makeOnboarding() -> (PaydaySetupPresenter, FakeOnboardingView, FakeInteractor, FakeOnboardingRouter) {
        let view = FakeOnboardingView(), interactor = FakeInteractor(), router = FakeOnboardingRouter()
        return (PaydaySetupPresenter(view: view, interactor: interactor, router: router), view, interactor, router)
    }

    func testOnboardingShowsOnlyRuleAndDay() {
        let (presenter, view, _, _) = makeOnboarding()
        presenter.viewDidLoad()
        let content = view.content
        XCTAssertEqual(content?.heading, "When's payday?")
        XCTAssertEqual(content?.choices.map(\.title),
                       ["Same date every month", "Last working day", "Twice a month", "No fixed payday"])
        XCTAssertEqual(content?.choices.map(\.selected), [true, false, false, false])
        XCTAssertEqual(content?.choices.first?.hint, "On the 25th")
        XCTAssertEqual(content?.detail?.title, "Day of month")
        XCTAssertEqual(content?.detail?.format(25), "25th")
        XCTAssertEqual(content?.notice, "We'll ask to send payday reminders next.")
        XCTAssertTrue(content?.continueTitle.hasPrefix("Continue · next payday ") == true)
    }

    func testOnboardingSwapsDetailForRule() {
        let (presenter, view, _, _) = makeOnboarding()
        presenter.viewDidLoad()
        presenter.selectChoice(at: 1)
        XCTAssertNil(view.details.last ?? nil)
        presenter.selectChoice(at: 3)
        XCTAssertEqual(view.details.last??.title, "Wait length")
        presenter.detailChanged(10)
        XCTAssertEqual(view.choices.last?.last?.hint, "Use a fixed wait instead (10 days)")
    }

    func testOnboardingReselectingSameChoiceDoesNothing() {
        let (presenter, view, _, _) = makeOnboarding()
        presenter.viewDidLoad()
        presenter.selectChoice(at: 0)
        XCTAssertTrue(view.choices.isEmpty)
    }

    func testContinueSavesWithPermissionAndFinishes() {
        let (presenter, view, interactor, router) = makeOnboarding()
        interactor.settings.funMoney = 999
        presenter.viewDidLoad()
        presenter.selectChoice(at: 2)
        presenter.detailChanged(10)
        presenter.tapContinue()
        XCTAssertEqual(interactor.saved.count, 1)
        XCTAssertEqual(interactor.permissions, [true])
        XCTAssertEqual(router.finished, 1)
        XCTAssertEqual(view.feedback, 1)
        let saved = interactor.saved.first
        XCTAssertEqual(saved?.rule, .twiceMonthly(first: 10, second: 31))
        XCTAssertEqual(saved?.reviewHour, PaydaySettings.default.reviewHour)
        XCTAssertEqual(saved?.reviewMinute, PaydaySettings.default.reviewMinute)
        XCTAssertEqual(saved?.funMoney, PaydaySettings.default.funMoney)
        XCTAssertEqual(saved?.timerThreshold, PaydaySettings.default.timerThreshold)
        XCTAssertEqual(saved?.timerDays, PaydaySettings.default.timerDays)
    }

    // MARK: Settings

    private final class FakeSettingsView: SettingsViewProtocol {
        var content: SettingsContent?
        var renders = 0
        var feedback = 0
        var appearance: AppearanceMode?
        func render(_ content: SettingsContent) { self.content = content; renders += 1 }
        func applyAppearance(_ mode: AppearanceMode) { appearance = mode }
        func playSaveFeedback() { feedback += 1 }

        @MainActor func row(_ id: SettingsRowID) -> SettingsRowViewModel? {
            content?.sections.flatMap(\.rows).first { $0.id == id }
        }
    }

    private final class FakeSettingsRouter: SettingsRouterProtocol {
        var shown = 0
        func showPaydayRule() { shown += 1 }
    }

    private func makeSettings() -> (SettingsPresenter, FakeSettingsView, FakeInteractor, FakeSettingsRouter) {
        let view = FakeSettingsView(), interactor = FakeInteractor(), router = FakeSettingsRouter()
        let presenter = SettingsPresenter(view: view, interactor: interactor, router: router)
        presenter.viewDidLoad()
        return (presenter, view, interactor, router)
    }

    func testSettingsContent() {
        let (_, view, _, _) = makeSettings()
        XCTAssertEqual(view.content?.title, "Settings")
        XCTAssertEqual(view.content?.sections.map(\.header), ["Payday", "Budget", "Quick thaws", "Appearance", "Reminders"])
        XCTAssertEqual(view.content?.sections[2].footer, "Cheaper wants use a timer instead of waiting for payday.")
        XCTAssertEqual(view.content?.sections.last?.footer,
                       "Entered by you, kept on this phone. Thaw never reads your bank.")
        XCTAssertEqual(view.row(.payday)?.value, "Same date · 25th")
        XCTAssertEqual(view.row(.payday)?.control, .disclosure)
        XCTAssertEqual(view.row(.funMoney)?.value, "S$300")
        XCTAssertEqual(view.row(.funMoney)?.control, .amount(editText: "300"))
        XCTAssertEqual(view.row(.timerThreshold)?.value, "S$30")
        XCTAssertEqual(view.row(.timerDays)?.control, .stepper(value: 2, minimum: 1, maximum: 14))
        XCTAssertEqual(view.row(.timerDays)?.value, "2 days")
        XCTAssertEqual(view.row(.reviewTime)?.control, .time(minutes: 540))
        XCTAssertEqual(view.row(.reviewTime)?.accessibilityValue, "9:00 am")
        let expected = PaydayRuleModel.nextPaydayText(.default)
        XCTAssertEqual(view.row(.nextPayday)?.value, expected)
    }

    func testAppearanceChangeIsSavedAndApplied() {
        let original = AppearanceMode.saved
        defer { AppearanceMode.saved = original }
        AppearanceMode.saved = .system
        let (presenter, view, interactor, _) = makeSettings()
        XCTAssertEqual(view.row(.appearance)?.control, .appearance(.system))
        presenter.appearanceChanged(.dark)
        XCTAssertEqual(AppearanceMode.saved, .dark)
        XCTAssertEqual(view.appearance, .dark)
        XCTAssertEqual(view.row(.appearance)?.control, .appearance(.dark))
        XCTAssertTrue(interactor.saved.isEmpty)
    }

    func testEachSettingsChangeSavesOnceWithoutPermission() {
        let (presenter, view, interactor, _) = makeSettings()
        presenter.amountEdited(.funMoney, text: "450")
        XCTAssertEqual(interactor.saved.count, 1)
        XCTAssertEqual(interactor.saved.last?.funMoney, 450)

        presenter.amountEdited(.timerThreshold, text: "S$40.6")
        XCTAssertEqual(interactor.saved.count, 2)
        XCTAssertEqual(interactor.saved.last?.timerThreshold, 41)

        presenter.stepperChanged(.timerDays, value: 3)
        XCTAssertEqual(interactor.saved.count, 3)
        XCTAssertEqual(interactor.saved.last?.timerDays, 3)

        presenter.reviewTimeChanged(minutes: 18 * 60 + 30)
        XCTAssertEqual(interactor.saved.count, 4)
        XCTAssertEqual(interactor.saved.last?.reviewHour, 18)
        XCTAssertEqual(interactor.saved.last?.reviewMinute, 30)

        XCTAssertEqual(interactor.permissions, [false, false, false, false])
        XCTAssertEqual(view.feedback, 4)
        XCTAssertEqual(view.row(.funMoney)?.value, "S$450")
        XCTAssertEqual(interactor.saved.last?.funMoney, 450)
    }

    func testUnchangedValueDoesNotSave() {
        let (presenter, view, interactor, _) = makeSettings()
        presenter.amountEdited(.funMoney, text: "300")
        presenter.stepperChanged(.timerDays, value: 2)
        presenter.reviewTimeChanged(minutes: 540)
        XCTAssertTrue(interactor.saved.isEmpty)
        XCTAssertEqual(view.feedback, 0)
    }

    func testInvalidAmountKeepsOldValue() {
        let (presenter, view, interactor, _) = makeSettings()
        for text in ["abc", "-5", "", "12abc"] {
            presenter.amountEdited(.funMoney, text: text)
        }
        XCTAssertTrue(interactor.saved.isEmpty)
        XCTAssertEqual(view.row(.funMoney)?.value, "S$300")
        XCTAssertEqual(view.row(.funMoney)?.control, .amount(editText: "300"))
    }

    func testAmountsAboveCapAreClamped() {
        let (presenter, _, interactor, _) = makeSettings()
        presenter.amountEdited(.funMoney, text: "250000")
        XCTAssertEqual(interactor.saved.last?.funMoney, 100_000)
        presenter.amountEdited(.timerThreshold, text: "20,000")
        XCTAssertEqual(interactor.saved.last?.timerThreshold, 10_000)
        presenter.stepperChanged(.timerDays, value: 40)
        XCTAssertEqual(interactor.saved.last?.timerDays, 14)
    }

    func testTimeMinutesMapToHourAndMinute() {
        let (presenter, _, interactor, _) = makeSettings()
        presenter.reviewTimeChanged(minutes: 0)
        XCTAssertEqual(interactor.saved.last.map { [$0.reviewHour, $0.reviewMinute] }, [0, 0])
        presenter.reviewTimeChanged(minutes: 23 * 60 + 45)
        XCTAssertEqual(interactor.saved.last.map { [$0.reviewHour, $0.reviewMinute] }, [23, 45])
        presenter.reviewTimeChanged(minutes: 7 * 60 + 15)
        XCTAssertEqual(interactor.saved.last.map { [$0.reviewHour, $0.reviewMinute] }, [7, 15])
    }

    func testPaydayRowPushesRuleScreenAndExternalChangesReload() {
        let (presenter, view, interactor, router) = makeSettings()
        presenter.tapRow(.payday)
        presenter.tapRow(.nextPayday)
        XCTAssertEqual(router.shown, 1)

        interactor.settings.rule = .lastWorkingDay
        presenter.settingsDidChange()
        XCTAssertEqual(view.row(.payday)?.value, "Last working day")
        XCTAssertTrue(interactor.saved.isEmpty)
    }

    // MARK: Rule screen

    private final class FakeRuleView: PaydayRuleViewProtocol {
        var content: PaydayRuleContent?
        var feedback = 0
        func render(_ content: PaydayRuleContent) { self.content = content }
        func playSaveFeedback() { feedback += 1 }
    }

    private func makeRule(_ settings: PaydaySettings = .default) -> (PaydayRulePresenter, FakeRuleView, FakeInteractor) {
        let view = FakeRuleView(), interactor = FakeInteractor()
        interactor.settings = settings
        let presenter = PaydayRulePresenter(view: view, interactor: interactor)
        presenter.viewDidLoad()
        return (presenter, view, interactor)
    }

    func testSelectingRuleSavesIt() {
        var settings = PaydaySettings.default
        settings.funMoney = 800
        let (presenter, view, interactor) = makeRule(settings)
        XCTAssertEqual(view.content?.options.map(\.selected), [true, false, false, false])
        presenter.selectRule(at: 1)
        XCTAssertEqual(interactor.saved.count, 1)
        XCTAssertEqual(interactor.saved.last?.rule, .lastWorkingDay)
        XCTAssertEqual(interactor.saved.last?.funMoney, 800)
        XCTAssertEqual(interactor.permissions, [false])
        XCTAssertEqual(view.content?.options.map(\.selected), [false, true, false, false])
        XCTAssertEqual(view.feedback, 1)

        presenter.selectRule(at: 1)
        XCTAssertEqual(interactor.saved.count, 1)
    }

    func testDaySectionOnlyForRulesThatNeedIt() {
        let (presenter, view, interactor) = makeRule()
        XCTAssertEqual(view.content?.day?.title, "Day of month")
        XCTAssertEqual(view.content?.day.map { [$0.minimum, $0.maximum, $0.value] }, [1, 31, 25])
        presenter.selectRule(at: 1)
        XCTAssertNil(view.content?.day)
        presenter.selectRule(at: 2)
        XCTAssertEqual(view.content?.day.map { [$0.minimum, $0.maximum] }, [1, 28])
        presenter.selectRule(at: 3)
        XCTAssertEqual(view.content?.day?.title, "Wait length")
        XCTAssertEqual(view.content?.day.map { [$0.minimum, $0.maximum] }, [1, 60])
        presenter.dayChanged(10)
        XCTAssertEqual(interactor.saved.last?.rule, .fixedWait(days: 10))
        XCTAssertEqual(view.content?.day?.valueText, "10 days")
    }

    func testNextPaydayTextUpdates() {
        let (presenter, view, interactor) = makeRule()
        let before = view.content?.nextPayday
        XCTAssertEqual(before, PaydayRuleModel.nextPaydayText(.default))
        presenter.selectRule(at: 3)
        presenter.dayChanged(40)
        XCTAssertEqual(view.content?.nextPayday, PaydayRuleModel.nextPaydayText(interactor.settings))
        let expected = Calendar.current.date(byAdding: .day, value: 40, to: Calendar.current.startOfDay(for: .now))!
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_SG")
        formatter.dateFormat = "d MMM"
        XCTAssertEqual(view.content?.nextPayday, formatter.string(from: expected))
    }

    // MARK: Integration

    private struct SilentScheduler: NotificationScheduling {
        func requestAuthorizationIfNeeded() async -> Bool { false }
        func schedulePaydayReview(at: Date, thawingCount: Int, total: Decimal) async {}
        func scheduleTimerThaw(wantID: UUID, name: String, at: Date) async {}
        func scheduleReminder(at: Date, thawingCount: Int, total: Decimal) async {}
        func cancelAll() async {}
    }

    func testSettingsPersistAcrossScreensAndRelaunch() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("PaydaySetup-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("state.json")
        let store = WantStore(fileURL: fileURL)
        store.save(settings: .default)
        let reminders = Reminders(store: store) { _ in SilentScheduler() }

        let settingsView = FakeSettingsView()
        let settingsInteractor = PaydaySetupInteractor(store: store, reminders: reminders)
        let settings = SettingsPresenter(view: settingsView, interactor: settingsInteractor, router: FakeSettingsRouter())
        settingsInteractor.output = settings
        settings.viewDidLoad()
        settings.amountEdited(.funMoney, text: "1240")
        settings.reviewTimeChanged(minutes: 20 * 60 + 15)

        let ruleView = FakeRuleView()
        let ruleInteractor = PaydaySetupInteractor(store: store, reminders: reminders)
        let rule = PaydayRulePresenter(view: ruleView, interactor: ruleInteractor)
        ruleInteractor.output = rule
        rule.viewDidLoad()
        rule.selectRule(at: 3)
        rule.dayChanged(12)

        XCTAssertEqual(settingsView.row(.payday)?.value, "Every 12 days")
        XCTAssertEqual(settingsView.row(.nextPayday)?.value, ruleView.content?.nextPayday)
        XCTAssertEqual(settingsView.row(.funMoney)?.value, "S$1,240")

        let relaunched = WantStore(fileURL: fileURL).effectiveSettings
        XCTAssertEqual(relaunched.rule, .fixedWait(days: 12))
        XCTAssertEqual(relaunched.funMoney, 1240)
        XCTAssertEqual(relaunched.reviewHour, 20)
        XCTAssertEqual(relaunched.reviewMinute, 15)
    }

    // MARK: Formatting

    func testOrdinals() {
        XCTAssertEqual(PaydaySetupPresenter.ordinal(1), "1st")
        XCTAssertEqual(PaydaySetupPresenter.ordinal(12), "12th")
        XCTAssertEqual(PaydaySetupPresenter.ordinal(22), "22nd")
        XCTAssertEqual(PaydaySetupPresenter.ordinal(23), "23rd")
    }

    func testTimeText() {
        XCTAssertEqual(PaydaySetupPresenter.timeText(0), "12:00 am")
        XCTAssertEqual(PaydaySetupPresenter.timeText(540), "9:00 am")
        XCTAssertEqual(PaydaySetupPresenter.timeText(12 * 60), "12:00 pm")
        XCTAssertEqual(PaydaySetupPresenter.timeText(18 * 60 + 30), "6:30 pm")
    }
}
