import Foundation

/// The Settings tab: a grouped list that saves each change straight away.
final class SettingsPresenter: SettingsPresenterProtocol, PaydaySetupInteractorOutput {
    static let funMoneyCap = 100_000
    static let timerThresholdCap = 10_000
    static let timerDaysRange = 1...14

    private weak var view: SettingsViewProtocol?
    private let interactor: PaydaySetupInteractorProtocol
    private let router: SettingsRouterProtocol
    private var settings: PaydaySettings

    // Explicit deinit: the synthesized one on a MainActor class with weak refs corrupts the heap in the test host.
    deinit {}

    init(view: SettingsViewProtocol, interactor: PaydaySetupInteractorProtocol, router: SettingsRouterProtocol) {
        self.view = view
        self.interactor = interactor
        self.router = router
        settings = interactor.settings
    }

    // MARK: Events

    func viewDidLoad() { render() }

    func viewWillAppear() { reload() }

    func settingsDidChange() { reload() }

    func tapRow(_ id: SettingsRowID) {
        if id == .payday { router.showPaydayRule() }
    }

    func amountEdited(_ id: SettingsRowID, text: String) {
        let cap: Int
        switch id {
        case .funMoney: cap = Self.funMoneyCap
        case .timerThreshold: cap = Self.timerThresholdCap
        default: return
        }
        guard let amount = Self.parseAmount(text, cap: cap) else {
            render()
            return
        }
        var updated = settings
        if id == .funMoney { updated.funMoney = Decimal(amount) } else { updated.timerThreshold = Decimal(amount) }
        save(updated)
    }

    func stepperChanged(_ id: SettingsRowID, value: Int) {
        guard id == .timerDays else { return }
        var updated = settings
        updated.timerDays = min(max(value, Self.timerDaysRange.lowerBound), Self.timerDaysRange.upperBound)
        save(updated)
    }

    func reviewTimeChanged(minutes: Int) {
        let clamped = min(max(minutes, 0), 24 * 60 - 1)
        var updated = settings
        updated.reviewHour = clamped / 60
        updated.reviewMinute = clamped % 60
        save(updated)
    }

    // MARK: Saving

    private func save(_ updated: PaydaySettings) {
        guard updated != settings else {
            render()
            return
        }
        settings = updated
        interactor.save(updated, requestingPermission: false)
        render()
        view?.playSaveFeedback()
    }

    private func reload() {
        settings = interactor.settings
        render()
    }

    /// Whole dollars from user text, clamped to `0...cap`; nil for empty, non-numeric or negative input.
    static func parseAmount(_ text: String, cap: Int, locale: Locale = .current) -> Int? {
        var cleaned = text.replacingOccurrences(of: "S$", with: "").replacingOccurrences(of: "$", with: "")
        cleaned = cleaned.filter { !$0.isWhitespace }
        if locale.decimalSeparator == "," {
            cleaned = cleaned.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        } else {
            cleaned = cleaned.replacingOccurrences(of: ",", with: "")
        }
        guard !cleaned.isEmpty, let value = Double(cleaned), value.isFinite, value >= 0 else { return nil }
        return Int(min(value.rounded(), Double(cap)))
    }

    // MARK: Content

    private func render() {
        view?.render(content)
    }

    var content: SettingsContent {
        let rule = PaydayRuleModel(rule: settings.rule)
        let nextPayday = PaydayRuleModel.nextPaydayText(settings)
        let reviewMinutes = settings.reviewHour * 60 + settings.reviewMinute
        let reviewText = PaydaySetupPresenter.timeText(Double(reviewMinutes))
        let funMoney = Formatting.sgd(settings.funMoney)
        let threshold = Formatting.sgd(settings.timerThreshold)
        let timer = PaydayRuleModel.daysText(settings.timerDays)
        return SettingsContent(title: "Settings", sections: [
            SettingsSectionViewModel(id: "payday", header: "Payday", footer: nil, rows: [
                SettingsRowViewModel(id: .payday, title: "Payday", value: rule.summary,
                                     accessibilityLabel: "Payday", accessibilityValue: rule.spokenSummary,
                                     control: .disclosure),
                SettingsRowViewModel(id: .nextPayday, title: "Next payday", value: nextPayday,
                                     accessibilityLabel: "Next payday", accessibilityValue: nextPayday,
                                     control: .readOnly),
            ]),
            SettingsSectionViewModel(id: "budget", header: "Budget", footer: nil, rows: [
                SettingsRowViewModel(id: .funMoney, title: "Fun money", value: funMoney,
                                     accessibilityLabel: "Fun money each payday",
                                     accessibilityValue: funMoney,
                                     control: .amount(editText: Self.editText(settings.funMoney))),
            ]),
            SettingsSectionViewModel(id: "quickThaws", header: "Quick thaws",
                                     footer: "Cheaper wants use a timer instead of waiting for payday.", rows: [
                SettingsRowViewModel(id: .timerThreshold, title: "Timer for wants under", value: threshold,
                                     accessibilityLabel: "Use a timer for wants under",
                                     accessibilityValue: threshold,
                                     control: .amount(editText: Self.editText(settings.timerThreshold))),
                SettingsRowViewModel(id: .timerDays, title: "Timer", value: timer,
                                     accessibilityLabel: "Timer length", accessibilityValue: timer,
                                     control: .stepper(value: settings.timerDays,
                                                       minimum: Self.timerDaysRange.lowerBound,
                                                       maximum: Self.timerDaysRange.upperBound)),
            ]),
            SettingsSectionViewModel(id: "reminders", header: "Reminders",
                                     footer: "Entered by you, kept on this phone. Thaw never reads your bank.", rows: [
                SettingsRowViewModel(id: .reviewTime, title: "Payday review at", value: reviewText,
                                     accessibilityLabel: "Payday review at", accessibilityValue: reviewText,
                                     control: .time(minutes: reviewMinutes)),
            ]),
        ])
    }

    private static func editText(_ value: Decimal) -> String {
        "\(Int(truncating: NSDecimalNumber(decimal: value)))"
    }
}
