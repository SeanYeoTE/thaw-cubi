import Foundation

/// A number the chosen payday rule needs (day of month, first payday or wait length).
struct RuleDayViewModel: Equatable {
    let title: String
    let minimum: Int
    let maximum: Int
    let value: Int
    let options: [String]

    var valueText: String { options[value - minimum] }
}

/// Payday-rule state and copy shared by onboarding and the Settings rule screen.
struct PaydayRuleModel: Equatable {
    enum Kind: CaseIterable { case sameDate, lastWorkingDay, twiceMonthly, fixedWait }

    var kind: Kind = .sameDate
    var day = 25
    var firstDay = 15
    var waitDays = 7

    init(rule: PaydayRule) {
        switch rule {
        case .sameDate(let value): kind = .sameDate; day = value
        case .lastWorkingDay: kind = .lastWorkingDay
        case .twiceMonthly(let first, _): kind = .twiceMonthly; firstDay = first
        case .fixedWait(let days): kind = .fixedWait; waitDays = days
        }
    }

    var rule: PaydayRule {
        switch kind {
        case .sameDate: .sameDate(day: day)
        case .lastWorkingDay: .lastWorkingDay
        case .twiceMonthly: .twiceMonthly(first: firstDay, second: 31)
        case .fixedWait: .fixedWait(days: waitDays)
        }
    }

    /// Selects the option at `index`; returns false when it is out of range or already selected.
    mutating func select(at index: Int) -> Bool {
        let options = Kind.allCases
        guard options.indices.contains(index), options[index] != kind else { return false }
        kind = options[index]
        return true
    }

    /// Sets the number for the current rule, clamped to its range; returns false when nothing changed.
    mutating func setDay(_ value: Int) -> Bool {
        guard let range = dayRange else { return false }
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        switch kind {
        case .sameDate: guard clamped != day else { return false }; day = clamped
        case .twiceMonthly: guard clamped != firstDay else { return false }; firstDay = clamped
        case .fixedWait: guard clamped != waitDays else { return false }; waitDays = clamped
        case .lastWorkingDay: return false
        }
        return true
    }

    private var dayRange: ClosedRange<Int>? {
        switch kind {
        case .sameDate: 1...31
        case .twiceMonthly: 1...28
        case .fixedWait: 1...60
        case .lastWorkingDay: nil
        }
    }

    // MARK: Copy

    static func title(_ kind: Kind) -> String {
        switch kind {
        case .sameDate: "Same date every month"
        case .lastWorkingDay: "Last working day"
        case .twiceMonthly: "Twice a month"
        case .fixedWait: "No fixed payday"
        }
    }

    /// Onboarding hint under each choice.
    func hint(_ option: Kind) -> String {
        switch option {
        case .sameDate: "On the \(Self.ordinal(day))"
        case .lastWorkingDay: "Moves around weekends"
        case .twiceMonthly: firstDay == 15 ? "e.g. the 15th and the last day" : "The \(Self.ordinal(firstDay)) and the last day"
        case .fixedWait: "Use a fixed wait instead (\(waitDays) days)"
        }
    }

    /// Settings rule-screen secondary text: one short line, only where it helps.
    func shortHint(_ option: Kind) -> String? {
        switch option {
        case .sameDate: nil
        case .lastWorkingDay: "Moves around weekends"
        case .twiceMonthly: "The \(Self.ordinal(firstDay)) and the last day"
        case .fixedWait: "A set wait instead"
        }
    }

    /// Settings summary, for example "Same date · 25th".
    var summary: String {
        switch kind {
        case .sameDate: "Same date · \(Self.ordinal(day))"
        case .lastWorkingDay: "Last working day"
        case .twiceMonthly: "Twice a month · \(Self.ordinal(firstDay))"
        case .fixedWait: "Every \(Self.daysText(waitDays))"
        }
    }

    /// Spoken summary for VoiceOver.
    var spokenSummary: String {
        switch kind {
        case .sameDate: "Same date every month, the \(Self.ordinal(day))"
        case .lastWorkingDay: "Last working day of the month"
        case .twiceMonthly: "Twice a month, the \(Self.ordinal(firstDay)) and the last day"
        case .fixedWait: "No fixed payday, wait \(Self.daysText(waitDays))"
        }
    }

    var dayViewModel: RuleDayViewModel? {
        guard let range = dayRange else { return nil }
        switch kind {
        case .sameDate:
            return RuleDayViewModel(title: "Day of month", minimum: range.lowerBound, maximum: range.upperBound,
                                    value: day, options: range.map(Self.ordinal))
        case .twiceMonthly:
            return RuleDayViewModel(title: "First payday", minimum: range.lowerBound, maximum: range.upperBound,
                                    value: firstDay, options: range.map(Self.ordinal))
        case .fixedWait:
            return RuleDayViewModel(title: "Wait length", minimum: range.lowerBound, maximum: range.upperBound,
                                    value: waitDays, options: range.map(Self.daysText))
        case .lastWorkingDay:
            return nil
        }
    }

    // MARK: Formatting

    static func nextPaydayText(_ settings: PaydaySettings, now: Date = .now, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_SG")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "d MMM"
        return formatter.string(from: settings.nextPayday(after: now, calendar: calendar))
    }

    static func daysText(_ value: Int) -> String {
        "\(value) \(value == 1 ? "day" : "days")"
    }

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
}
