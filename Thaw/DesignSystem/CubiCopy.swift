import Foundation

/// What Cubi says, kept apart from his drawing. It lives under DesignSystem only because the share extension compiles that folder.
extension CubiMood {
    var line: String {
        switch self {
        case .frozen: "Brr. See you on payday."
        case .thawing: "Still on your mind?"
        case .thawed: "I've thawed. Your call."
        case .proud: "That money stays with you."
        case .snoozing: "Back in the freezer till next payday."
        }
    }

    static func thawingLine(days: Int) -> String {
        "Still on your mind? Payday's in \(days) \(days == 1 ? "day" : "days")."
    }

    /// `amount` is the formatted figure, with or without the "S$" prefix.
    static func proudLine(amount: String) -> String {
        "\(amount.hasPrefix("S$") ? amount : "S$" + amount) stays with you."
    }

    func thawingLine(days: Int) -> String { Self.thawingLine(days: days) }
    func proudLine(amount: String) -> String { Self.proudLine(amount: amount) }
}
