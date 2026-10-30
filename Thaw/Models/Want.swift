import Foundation

nonisolated struct Want: Identifiable, Equatable {
    enum Status: Equatable {
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
