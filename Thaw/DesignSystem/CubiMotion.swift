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

    /// Slow loops that keep Cubi alive while he sits on a screen. Movement is additive, so it never fights the
    /// one-shot motion; fades use absolute values, because an additive fade on a fully opaque layer clamps to 1.
    static func idleSteps(for mood: CubiMood, reduceMotion: Bool = UIAccessibility.isReduceMotionEnabled) -> [Step] {
        guard !reduceMotion else { return [] }
        switch mood {
        case .frozen: // a quick shiver every few seconds
            let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
            shake.values = [0, 0, -2, 2, -2, 2, 0, 0]
            shake.keyTimes = [0, 0.7, 0.75, 0.8, 0.85, 0.9, 0.95, 1]
            shake.duration = 4
            return [Step(part: .body, animation: loop(shake, autoreverses: false))]
        case .thawing: // a drip that keeps forming
            let drop = CABasicAnimation(keyPath: "transform.translation.y")
            drop.fromValue = -4
            drop.toValue = 6
            let drip = group(drop, fade(from: 1, to: 0.2))
            drip.duration = 1.8
            return [Step(part: .prop, animation: loop(drip, autoreverses: false))]
        case .thawed: // a gentle bob
            return [Step(part: .body, animation: loop(bob(by: -3, duration: 1.2)))]
        case .proud: // the star twinkles
            return [
                Step(part: .body, animation: loop(bob(by: -2, duration: 1.6))),
                Step(part: .prop, animation: loop(fade(from: 1, to: 0.45, duration: 0.9))),
            ]
        case .snoozing: // slow breathing, the Zs drift
            return [
                Step(part: .body, animation: loop(bob(by: 2, duration: 1.8))),
                Step(part: .prop, animation: loop(bob(by: -4, duration: 1.4))),
            ]
        }
    }

    private static func bob(by distance: CGFloat, duration: CFTimeInterval) -> CABasicAnimation {
        let bob = CABasicAnimation(keyPath: "transform.translation.y")
        bob.fromValue = 0
        bob.toValue = distance
        bob.duration = duration
        bob.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        return bob
    }

    private static func loop(_ animation: CAAnimation, autoreverses: Bool = true) -> CAAnimation {
        animation.repeatCount = .infinity
        animation.autoreverses = autoreverses
        let parts = (animation as? CAAnimationGroup)?.animations ?? [animation]
        for case let property as CAPropertyAnimation in parts {
            property.isAdditive = property.keyPath?.hasPrefix("transform") == true || property.keyPath?.hasPrefix("position") == true
        }
        return animation
    }

    private static func fade(from: Float, to: Float, duration: CFTimeInterval? = nil) -> CABasicAnimation {
        let animation = fade(from: from, to: to)
        if let duration { animation.duration = duration }
        return animation
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
