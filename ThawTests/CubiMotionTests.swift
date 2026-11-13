import XCTest
@testable import Thaw

final class CubiMotionTests: XCTestCase {
    @MainActor func testReduceMotionPlaysNothing() {
        for mood in CubiMood.allCases {
            XCTAssertTrue(CubiMotion.steps(for: mood, reduceMotion: true).isEmpty)
        }
    }

    @MainActor func testEveryMoodHasMotion() {
        for mood in CubiMood.allCases {
            XCTAssertFalse(CubiMotion.steps(for: mood, reduceMotion: false).isEmpty, "\(mood)")
        }
    }

    @MainActor func testSizesAreDistinctRoles() {
        XCTAssertLessThan(CubiSize.inline.rawValue, CubiSize.card.rawValue)
        XCTAssertLessThan(CubiSize.card.rawValue, CubiSize.feature.rawValue)
    }

    @MainActor func testIdleLoopsForeverAndStopsUnderReduceMotion() {
        for mood in CubiMood.allCases {
            XCTAssertTrue(CubiMotion.idleSteps(for: mood, reduceMotion: true).isEmpty)
            let steps = CubiMotion.idleSteps(for: mood, reduceMotion: false)
            XCTAssertFalse(steps.isEmpty, "\(mood)")
            for step in steps {
                XCTAssertEqual(step.animation.repeatCount, .infinity, "\(mood)")
                let parts = (step.animation as? CAAnimationGroup)?.animations ?? [step.animation]
                for case let property as CAPropertyAnimation in parts {
                    if property.keyPath == "opacity" {
                        XCTAssertFalse(property.isAdditive, "\(mood) opacity must be absolute to show")
                    } else {
                        XCTAssertTrue(property.isAdditive, "\(mood) \(property.keyPath ?? "")")
                    }
                }
            }
        }
    }

    @MainActor func testIdleFadesUseAbsoluteOpacity() {
        let fades = [CubiMood.proud, .thawing].flatMap { mood in
            CubiMotion.idleSteps(for: mood, reduceMotion: false).flatMap { step in
                ((step.animation as? CAAnimationGroup)?.animations ?? [step.animation])
                    .compactMap { $0 as? CABasicAnimation }
                    .filter { $0.keyPath == "opacity" }
            }
        }
        XCTAssertEqual(fades.count, 2, "the proud twinkle and the thawing drip both fade")
        for fade in fades {
            XCTAssertFalse(fade.isAdditive)
            XCTAssertEqual(fade.fromValue as? Float, 1)
            XCTAssertLessThan(fade.toValue as? Float ?? 1, 1)
        }
    }
}
