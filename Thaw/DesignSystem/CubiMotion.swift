import UIKit

/// The one-shot motion for each mood, as data. `CubiView` decides where each part plays.
enum CubiMotion {
    enum Part {
        /// Body, highlight and face move together.
        case body
        case prop
    }

    struct Step {
        let part: Part
        let animation: CAAnimation
    }

    /// Empty under Reduce Motion, so callers never have to check it themselves.
    static func steps(for mood: CubiMood, reduceMotion: Bool = UIAccessibility.isReduceMotionEnabled) -> [Step] {
        guard !reduceMotion else { return [] }
        switch mood {
        case .frozen: // shiver
            let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
            shake.values = [0, -3, 3, -2, 2, 0]
            shake.duration = 0.45
            return [Step(part: .body, animation: shake)]
        case .thawing: // drip
            let drop = CABasicAnimation(keyPath: "transform.translation.y")
            drop.fromValue = -6
            drop.toValue = 8
            return [Step(part: .prop, animation: group(drop, fade(from: 1, to: 0.2)))]
        case .thawed: // bounce
            let bounce = CAKeyframeAnimation(keyPath: "transform.translation.y")
            bounce.values = [0, -8, 0, -3, 0]
            bounce.duration = 0.5
            bounce.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeOut), count: 4)
            return [Step(part: .body, animation: bounce)]
        case .proud: // sparkle
            let pop = CAKeyframeAnimation(keyPath: "transform.scale")
            pop.values = [0.2, 1.3, 1]
            pop.duration = 0.5
            return [Step(part: .prop, animation: pop)]
        case .snoozing: // float
            let rise = CABasicAnimation(keyPath: "transform.translation.y")
            rise.fromValue = 8
            rise.toValue = 0
            return [Step(part: .prop, animation: group(rise, fade(from: 0, to: 1)))]
        }
    }

    private static func fade(from: Float, to: Float) -> CABasicAnimation {
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = from
        fade.toValue = to
        return fade
    }

    private static func group(_ animations: CAAnimation...) -> CAAnimationGroup {
        let group = CAAnimationGroup()
        group.animations = animations
        group.duration = 0.5
        return group
    }
}
