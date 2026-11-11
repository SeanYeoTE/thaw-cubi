import Foundation

/// Onboarding: one question, "When's payday?". Everything else keeps `PaydaySettings.default`.
final class PaydaySetupPresenter: PaydaySetupPresenterProtocol {
    private weak var view: PaydaySetupViewProtocol?
    private let interactor: PaydaySetupInteractorProtocol
    private let router: PaydaySetupRouterProtocol
    private var model = PaydayRuleModel(rule: PaydaySettings.default.rule)

    // Explicit deinit: the synthesized one on a MainActor class with weak refs corrupts the heap in the test host.
    deinit {}

    init(view: PaydaySetupViewProtocol, interactor: PaydaySetupInteractorProtocol, router: PaydaySetupRouterProtocol) {
        self.view = view
        self.interactor = interactor
        self.router = router
    }

    // MARK: Events

    func viewDidLoad() {
        view?.render(PaydaySetupContent(
            heading: "When's payday?",
            subtitle: "Wants thaw then, when you can actually afford them.",
            legend: "I get paid",
            choices: choices(),
            detail: detail(),
            notice: "We'll ask to send payday reminders next.",
            continueTitle: continueTitle
        ))
    }

    func selectChoice(at index: Int) {
        guard model.select(at: index) else { return }
        view?.renderChoices(choices())
        view?.renderDetail(detail())
        view?.updateContinueTitle(continueTitle)
    }

    func detailChanged(_ value: Double) {
        guard model.setDay(Int(value)) else { return }
        view?.renderChoices(choices())
        view?.updateContinueTitle(continueTitle)
    }

    func tapContinue() {
        interactor.save(currentSettings, requestingPermission: true)
        view?.playSuccessFeedback()
        router.finishOnboarding()
    }

    // MARK: State

    var currentSettings: PaydaySettings {
        var settings = PaydaySettings.default
        settings.rule = model.rule
        return settings
    }

    private var continueTitle: String {
        "Continue · next payday \(PaydayRuleModel.nextPaydayText(currentSettings))"
    }

    private func choices() -> [SetupChoiceViewModel] {
        PaydayRuleModel.Kind.allCases.map { option in
            SetupChoiceViewModel(title: PaydayRuleModel.title(option), hint: model.hint(option), selected: option == model.kind)
        }
    }

    private func detail() -> StepperViewModel? {
        guard let day = model.dayViewModel else { return nil }
        let subtitle: String?
        switch model.kind {
        case .twiceMonthly: subtitle = "The second is the last day"
        case .fixedWait: subtitle = "Days before a want thaws"
        default: subtitle = nil
        }
        return StepperViewModel(title: day.title, subtitle: subtitle, minimum: Double(day.minimum),
                                maximum: Double(day.maximum), step: 1, value: Double(day.value),
                                format: { day.options[Int($0) - day.minimum] })
    }

    // MARK: Formatting

    static func ordinal(_ value: Int) -> String { PaydayRuleModel.ordinal(value) }

    static func timeText(_ minutes: Double) -> String {
        let total = Int(minutes)
        let hour = total / 60, minute = total % 60
        let display = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%d:%02d %@", display, minute, hour < 12 ? "am" : "pm")
    }
}
