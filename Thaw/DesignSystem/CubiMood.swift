import Foundation

enum CubiMood: CaseIterable {
    case frozen, thawing, thawed, proud, snoozing

    var accessibilityName: String {
        switch self {
        case .frozen: "frozen"
        case .thawing: "thawing"
        case .thawed: "thawed"
        case .proud: "proud"
        case .snoozing: "snoozing"
        }
    }
}
