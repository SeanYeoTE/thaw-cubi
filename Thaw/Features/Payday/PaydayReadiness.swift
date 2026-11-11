import Foundation

/// What the Payday tab and its badge count as "ready": wants in the review queue whose thaw date has passed,
/// that is thawed timers plus payday wants once payday arrives. Payday wants sit in `reviewQueue` all month
/// (so a notification can open them early), but they only count as ready on the day they thaw.
nonisolated enum PaydayReadiness {
    static func ready(queue: [Want], now: Date) -> [Want] {
        queue.filter { $0.thawsAt <= now }
    }

    /// Tab badge text: the ready count, or nil when nothing is ready.
    static func badgeValue(readyCount: Int) -> String? {
        readyCount > 0 ? "\(readyCount)" : nil
    }

    /// The next moment a cooling want thaws, so the badge and screen can refresh with no data change.
    static func nextThaw(cooling: [Want], now: Date) -> Date? {
        cooling.map(\.thawsAt).filter { $0 > now }.min()
    }
}
