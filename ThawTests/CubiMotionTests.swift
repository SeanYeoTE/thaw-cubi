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
}
