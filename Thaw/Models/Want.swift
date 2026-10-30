import Foundation

nonisolated struct Want: Identifiable, Equatable, Codable, Sendable {
    enum Status: String, Equatable, Codable, Sendable {
        case cooling
        case skipped
        case bought
    }

    let id: UUID
    var name: String
    var price: Decimal
    var reason: String
    var frozenOn: Date
    var progress: Double
    var status: Status
    var thawsAt: Date

    init(id: UUID, name: String, price: Decimal, reason: String, frozenOn: Date,
         progress: Double, status: Status, thawsAt: Date? = nil) {
        self.id = id
        self.name = name
        self.price = price
        self.reason = reason
        self.frozenOn = frozenOn
        self.progress = progress
        self.status = status
        if let thawsAt {
            self.thawsAt = thawsAt
        } else {
            let settings = PaydaySettings.default
            self.thawsAt = price < settings.timerThreshold
                ? Calendar.current.date(byAdding: .day, value: settings.timerDays, to: frozenOn) ?? frozenOn
                : settings.nextPayday(after: frozenOn, calendar: .current)
        }
    }

    var isUnderTimerThreshold: Bool { price < CoolingRule.timerThreshold }
}

nonisolated enum CoolingRule {
    static let timerThreshold: Decimal = 30
    static let shortTimerDays = 2
}

nonisolated struct PaydaySchedule {
    let nextPayday: Date
    let funMoney: Decimal

    var daysUntilNext: Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: nextPayday).day ?? 0
    }
}

nonisolated enum PaydayRule: Codable, Equatable, Sendable {
    case sameDate(day: Int)
    case lastWorkingDay
    case twiceMonthly(first: Int, second: Int)
    case fixedWait(days: Int)
}

nonisolated struct PaydaySettings: Codable, Equatable, Sendable {
    var rule: PaydayRule
    var reviewHour: Int
    var reviewMinute: Int
    var funMoney: Decimal
    var timerThreshold: Decimal
    var timerDays: Int

    static let `default` = PaydaySettings(
        rule: .sameDate(day: 25), reviewHour: 9, reviewMinute: 0,
        funMoney: 300, timerThreshold: 30, timerDays: 2
    )

    /// First payday strictly after `after`, at the review time.
    func nextPayday(after: Date, calendar: Calendar) -> Date {
        if case .fixedWait(let days) = rule {
            let start = calendar.startOfDay(for: after)
            let target = calendar.date(byAdding: .day, value: max(days, 1), to: start) ?? start
            return applyingReviewTime(to: target, calendar: calendar)
        }
        let monthStart = calendar.dateInterval(of: .month, for: after)?.start ?? calendar.startOfDay(for: after)
        for offset in 0...2 {
            guard let month = calendar.date(byAdding: .month, value: offset, to: monthStart) else { continue }
            for day in paydays(inMonthStarting: month, calendar: calendar) {
                let candidate = applyingReviewTime(to: day, calendar: calendar)
                if candidate > after { return candidate }
            }
        }
        return applyingReviewTime(to: after.addingTimeInterval(30 * 86_400), calendar: calendar)
    }

    /// The payday following `payday`, used when a want waits one more payday.
    func paydayAfter(_ payday: Date, calendar: Calendar) -> Date {
        nextPayday(after: payday, calendar: calendar)
    }

    private func paydays(inMonthStarting month: Date, calendar: Calendar) -> [Date] {
        let length = calendar.range(of: .day, in: .month, for: month)?.count ?? 28
        func day(_ value: Int) -> Date {
            calendar.date(byAdding: .day, value: min(max(value, 1), length) - 1, to: month) ?? month
        }
        switch rule {
        case .sameDate(let value):
            return [day(value)]
        case .twiceMonthly(let first, let second):
            return [day(first), day(second)].sorted()
        case .lastWorkingDay:
            var last = day(length)
            while calendar.isDateInWeekend(last) {
                guard let previous = calendar.date(byAdding: .day, value: -1, to: last) else { break }
                last = previous
            }
            return [last]
        case .fixedWait:
            return []
        }
    }

    private func applyingReviewTime(to date: Date, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: min(max(reviewHour, 0), 23), minute: min(max(reviewMinute, 0), 59),
                      second: 0, of: date) ?? date
    }
}

nonisolated struct FunMoneySummary: Equatable, Sendable {
    let kept: Decimal
    let budget: Decimal

    var remaining: Decimal { budget - kept }
    var overBy: Decimal { max(0, kept - budget) }
    var fraction: Double {
        guard budget > 0 else { return kept > 0 ? 1 : 0 }
        return min(1, max(0, NSDecimalNumber(decimal: kept / budget).doubleValue))
    }

    static func make(keptPrices: [Decimal], budget: Decimal) -> FunMoneySummary {
        FunMoneySummary(kept: keptPrices.reduce(Decimal(0), +), budget: budget)
    }
}
