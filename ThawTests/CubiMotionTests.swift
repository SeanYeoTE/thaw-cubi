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
                    XCTAssertTrue(property.isAdditive, "\(mood)")
                }
            }
        }
    }
}
