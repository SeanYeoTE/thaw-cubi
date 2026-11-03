import Foundation

final class PaydaySetupPresenter: PaydaySetupPresenterProtocol {
    private enum Kind: CaseIterable { case sameDate, lastWorkingDay, twiceMonthly, fixedWait }

    private weak var view: PaydaySetupViewProtocol?
    private let interactor: PaydaySetupInteractorProtocol
    private let router: PaydaySetupRouterProtocol

    private var kind: Kind = .sameDate
    private var day = 25
    private var firstDay = 15
    private var waitDays = 7
    private var reviewMinutes: Int
    private var funMoney: Int
    private var timerThreshold: Int
    private var timerDays: Int

    // Explicit deinit: the synthesized one on a MainActor class with weak refs corrupts the heap in the test host.
    deinit {}

    init(view: PaydaySetupViewProtocol, interactor: PaydaySetupInteractorProtocol, router: PaydaySetupRouterProtocol) {
        self.view = view
        self.interactor = interactor
        self.router = router
        let current = interactor.settings
        switch current.rule {
        case .sameDate(let value): kind = .sameDate; day = value
        case .lastWorkingDay: kind = .lastWorkingDay
        case .twiceMonthly(let first, _): kind = .twiceMonthly; firstDay = first
        case .fixedWait(let days): kind = .fixedWait; waitDays = days
        }
        reviewMinutes = current.reviewHour * 60 + current.reviewMinute
        funMoney = Int(truncating: NSDecimalNumber(decimal: current.funMoney))
        timerThreshold = Int(truncating: NSDecimalNumber(decimal: current.timerThreshold))
        timerDays = current.timerDays
    }

    // MARK: Events

    func viewDidLoad() {
        view?.render(PaydaySetupContent(
            isOnboarding: router.isOnboarding,
            choices: choices(),
            detail: detail(),
            review: StepperViewModel(title: "Payday review at", subtitle: nil, minimum: 0, maximum: 1410, step: 30,
                                     value: Double(reviewMinutes), format: Self.timeText),
            funMoney: StepperViewModel(title: "Fun money each payday", subtitle: "Your limit for thawed wants",
                                       minimum: 0, maximum: 5000, step: 50, value: Double(funMoney),
                                       format: { Formatting.sgd(Decimal($0)) }),
            timerThreshold: StepperViewModel(title: "Use a timer for buys under",
                                             subtitle: "Cheap things don't wait for payday",
                                             minimum: 0, maximum: 500, step: 5, value: Double(timerThreshold),
                                             format: { Formatting.sgd(Decimal($0)) }),
            timerLength: StepperViewModel(title: "Timer length", subtitle: nil, minimum: 1, maximum: 14, step: 1,
                                          value: Double(timerDays),
                                          format: { "\(Int($0)) \(Int($0) == 1 ? "day" : "days")" }),
            saveTitle: saveTitle
        ))
    }

    func selectChoice(at index: Int) {
        let options = Kind.allCases
        guard options.indices.contains(index), options[index] != kind else { return }
        kind = options[index]
        view?.renderChoices(choices())
        view?.renderDetail(detail())
        view?.updateSaveTitle(saveTitle)
    }

    func detailChanged(_ value: Double) {
        let day = Int(value)
        switch kind {
        case .sameDate: self.day = day
        case .twiceMonthly: firstDay = day
        case .fixedWait: waitDays = day
        case .lastWorkingDay: break
        }
        view?.renderChoices(choices())
        view?.updateSaveTitle(saveTitle)
    }

    func reviewChanged(_ value: Double) {
        reviewMinutes = Int(value)
        view?.updateSaveTitle(saveTitle)
    }

    func funMoneyChanged(_ value: Double) { funMoney = Int(value) }

    func timerThresholdChanged(_ value: Double) { timerThreshold = Int(value) }

    func timerLengthChanged(_ value: Double) { timerDays = Int(value) }

    func tapSave() {
        interactor.save(currentSettings)
        view?.playSuccessFeedback()
        if router.isOnboarding {
            router.finishOnboarding()
        } else {
            view?.showSavedConfirmation()
        }
    }

    // MARK: State

    var currentSettings: PaydaySettings {
        PaydaySettings(rule: rule, reviewHour: reviewMinutes / 60, reviewMinute: reviewMinutes % 60,
                       funMoney: Decimal(funMoney), timerThreshold: Decimal(timerThreshold), timerDays: timerDays)
    }

    private var rule: PaydayRule {
        switch kind {
        case .sameDate: .sameDate(day: day)
        case .lastWorkingDay: .lastWorkingDay
        case .twiceMonthly: .twiceMonthly(first: firstDay, second: 31)
        case .fixedWait: .fixedWait(days: waitDays)
        }
    }

    private var saveTitle: String {
        let next = currentSettings.nextPayday(after: .now, calendar: .current)
        return "Save · next payday \(Formatting.paydayDate(next))"
    }

    private func choices() -> [SetupChoiceViewModel] {
        Kind.allCases.map { option in
            let copy = choiceCopy(option)
            return SetupChoiceViewModel(title: copy.title, hint: copy.hint, selected: option == kind)
        }
    }

    private func choiceCopy(_ kind: Kind) -> (title: String, hint: String) {
        switch kind {
        case .sameDate:
            return ("Same date every month", "On the \(Self.ordinal(day))")
        case .lastWorkingDay:
            return ("Last working day", "Moves around weekends")
        case .twiceMonthly:
            return ("Twice a month", firstDay == 15 ? "e.g. the 15th and the last day"
                                                    : "The \(Self.ordinal(firstDay)) and the last day")
        case .fixedWait:
            return ("No fixed payday", "Use a fixed wait instead (\(waitDays) days)")
        }
    }

    private func detail() -> StepperViewModel? {
        switch kind {
        case .lastWorkingDay:
            return nil
        case .sameDate:
            return StepperViewModel(title: "Payday date", subtitle: "Day of the month", minimum: 1, maximum: 31, step: 1,
                                    value: Double(day), format: { Self.ordinal(Int($0)) })
        case .twiceMonthly:
            return StepperViewModel(title: "First payday", subtitle: "The second is the last day", minimum: 1, maximum: 28,
                                    step: 1, value: Double(firstDay), format: { Self.ordinal(Int($0)) })
        case .fixedWait:
            return StepperViewModel(title: "Wait length", subtitle: "Days before a want thaws", minimum: 1, maximum: 60,
                                    step: 1, value: Double(waitDays), format: { "\(Int($0)) days" })
        }
    }

    // MARK: Formatting

    static func ordinal(_ value: Int) -> String {
        let suffix: String
        switch value % 100 {
        case 11...13: suffix = "th"
        default:
            switch value % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(value)\(suffix)"
    }

    static func timeText(_ minutes: Double) -> String {
        let total = Int(minutes)
        let hour = total / 60, minute = total % 60
        let display = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%d:%02d %@", display, minute, hour < 12 ? "am" : "pm")
    }
}
