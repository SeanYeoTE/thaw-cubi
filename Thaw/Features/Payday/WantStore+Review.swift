import Foundation

extension WantStore {
    /// Wants to review on payday: everything already thawed plus payday wants due by the next payday.
    var reviewQueue: [Want] {
        let thawed = Set(thawedWants.map(\.id))
        let threshold = effectiveSettings.timerThreshold
        let nextPayday = payday.nextPayday
        return cooling.filter { thawed.contains($0.id) || ($0.price >= threshold && $0.thawsAt <= nextPayday) }
    }
}
