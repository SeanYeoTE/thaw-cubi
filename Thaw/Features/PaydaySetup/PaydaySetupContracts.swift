import Foundation

// MARK: Shared

protocol PaydaySetupInteractorProtocol: AnyObject {
    var output: PaydaySetupInteractorOutput? { get set }
    var settings: PaydaySettings { get }
    /// Persists the settings, refreshes reminders (asking for permission only when told to) and posts `DataChange`.
    func save(_ settings: PaydaySettings, requestingPermission: Bool)
}

protocol PaydaySetupInteractorOutput: AnyObject {
    func settingsDidChange()
}

// MARK: Onboarding

struct SetupChoiceViewModel: Equatable {
    let title: String
    let hint: String
    let selected: Bool
}

struct StepperViewModel {
    let title: String
    let subtitle: String?
    let minimum: Double
    let maximum: Double
    let step: Double
    let value: Double
    let format: (Double) -> String
}

struct PaydaySetupContent {
    let heading: String
    let subtitle: String
    let legend: String
    let choices: [SetupChoiceViewModel]
    let detail: StepperViewModel?
    let notice: String
    let continueTitle: String
}

protocol PaydaySetupViewProtocol: AnyObject {
    func render(_ content: PaydaySetupContent)
    func renderChoices(_ choices: [SetupChoiceViewModel])
    func renderDetail(_ detail: StepperViewModel?)
    func updateContinueTitle(_ title: String)
    func playSuccessFeedback()
}

protocol PaydaySetupPresenterProtocol: AnyObject {
    func viewDidLoad()
    func selectChoice(at index: Int)
    func detailChanged(_ value: Double)
    func tapContinue()
}

protocol PaydaySetupRouterProtocol: AnyObject {
    func finishOnboarding()
}

// MARK: Settings tab

nonisolated enum SettingsRowID: Hashable {
    case payday, nextPayday, funMoney, timerThreshold, timerDays, reviewTime
}

struct SettingsRowViewModel: Equatable {
    enum Control: Equatable {
        case disclosure
        case readOnly
        /// Inline amount field; `editText` is the bare number shown while editing.
        case amount(editText: String)
        case stepper(value: Int, minimum: Int, maximum: Int)
        /// Time picker; minutes since midnight.
        case time(minutes: Int)
    }

    let id: SettingsRowID
    let title: String
    let value: String
    let accessibilityLabel: String
    let accessibilityValue: String
    let control: Control
}

struct SettingsSectionViewModel: Equatable {
    let id: String
    let header: String?
    let footer: String?
    let rows: [SettingsRowViewModel]
}

struct SettingsContent: Equatable {
    let title: String
    let sections: [SettingsSectionViewModel]
}

protocol SettingsViewProtocol: AnyObject {
    func render(_ content: SettingsContent)
    func playSaveFeedback()
}

protocol SettingsPresenterProtocol: AnyObject {
    func viewDidLoad()
    func viewWillAppear()
    func tapRow(_ id: SettingsRowID)
    /// Called when an amount field ends editing, with the raw text.
    func amountEdited(_ id: SettingsRowID, text: String)
    func stepperChanged(_ id: SettingsRowID, value: Int)
    func reviewTimeChanged(minutes: Int)
}

protocol SettingsRouterProtocol: AnyObject {
    func showPaydayRule()
}

// MARK: Payday rule screen

struct PaydayRuleOptionViewModel: Equatable {
    let title: String
    let hint: String?
    let selected: Bool
}

struct PaydayRuleContent: Equatable {
    let title: String
    let options: [PaydayRuleOptionViewModel]
    let day: RuleDayViewModel?
    let nextPaydayTitle: String
    let nextPayday: String
}

protocol PaydayRuleViewProtocol: AnyObject {
    func render(_ content: PaydayRuleContent)
    func playSaveFeedback()
}

protocol PaydayRulePresenterProtocol: AnyObject {
    func viewDidLoad()
    func selectRule(at index: Int)
    func dayChanged(_ value: Int)
}
