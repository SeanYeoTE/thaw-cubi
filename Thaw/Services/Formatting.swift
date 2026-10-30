import Foundation

nonisolated enum Formatting {
    static func sgd(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = ","
        let number = NSDecimalNumber(decimal: value)
        return "S$" + (formatter.string(from: number) ?? "\(value)")
    }

    static func paydayDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_SG")
        formatter.dateFormat = "EEE, d MMM"
        return formatter.string(from: date)
    }
}
