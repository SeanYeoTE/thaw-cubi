import Foundation

nonisolated struct ProgressStats: Equatable, Sendable {
    let saved: Decimal
    let skippedCount: Int
    let decidedCount: Int
    let streak: Int
    let funMoneyMonths: Double

    var winRatePercent: Int {
        decidedCount == 0 ? 0 : Int((Double(skippedCount) / Double(decidedCount) * 100).rounded())
    }

    /// Streak counts consecutive months, ending this month or last, in which a want was skipped.
    /// A skipped want belongs to the month of its `decisionDate`, when it was skipped.
    static func make(wants: [Want], funMoney: Decimal, now: Date = .now, calendar: Calendar = .current) -> ProgressStats {
        let skipped = wants.filter { $0.status == .skipped }
        let decided = wants.filter { $0.status != .cooling }
        let saved = skipped.reduce(Decimal(0)) { $0 + $1.price }

        func monthIndex(_ date: Date) -> Int {
            let c = calendar.dateComponents([.year, .month], from: date)
            return (c.year ?? 0) * 12 + (c.month ?? 1)
        }
        let months = Set(skipped.map { monthIndex($0.decisionDate) })
        let current = monthIndex(now)
        var cursor = months.contains(current) ? current : current - 1
        var streak = 0
        while months.contains(cursor) {
            streak += 1
            cursor -= 1
        }

        let months_ = funMoney > 0 ? NSDecimalNumber(decimal: saved / funMoney).doubleValue : 0
        return ProgressStats(saved: saved, skippedCount: skipped.count, decidedCount: decided.count,
                             streak: streak, funMoneyMonths: months_)
    }
}
