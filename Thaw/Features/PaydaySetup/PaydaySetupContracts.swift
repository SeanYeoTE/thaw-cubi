import Foundation

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
    let isOnboarding: Bool
    let choices: [SetupChoiceViewModel]
    let detail: StepperViewModel?
    let review: StepperViewModel
    let funMoney: StepperViewModel
    let timerThreshold: StepperViewModel
    let timerLength: StepperViewModel
    let saveTitle: String
}

protocol PaydaySetupViewProtocol: AnyObject {
    func render(_ content: PaydaySetupContent)
    func renderChoices(_ choices: [SetupChoiceViewModel])
    func renderDetail(_ detail: StepperViewModel?)
    func updateSaveTitle(_ title: String)
    func showSavedConfirmation()
    func playSuccessFeedback()
}

protocol PaydaySetupPresenterProtocol: AnyObject {
    func viewDidLoad()
    func selectChoice(at index: Int)
    func detailChanged(_ value: Double)
    func reviewChanged(_ value: Double)
    func funMoneyChanged(_ value: Double)
    func timerThresholdChanged(_ value: Double)
    func timerLengthChanged(_ value: Double)
    func tapSave()
}

protocol PaydaySetupInteractorProtocol: AnyObject {
    var settings: PaydaySettings { get }
    /// Persists the settings and asks for notification permission on first save.
    func save(_ settings: PaydaySettings)
}

protocol PaydaySetupRouterProtocol: AnyObject {
    var isOnboarding: Bool { get }
    func finishOnboarding()
}
