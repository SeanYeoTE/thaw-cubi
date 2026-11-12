import UIKit
import XCTest
@testable import Thaw

@MainActor
final class ThawColumnTests: XCTestCase {
    func testPhoneWidthKeepsScreenMargins() {
        let insets = ThawColumn.insets(containerWidth: 402, safeArea: .zero, top: 4, bottom: 8)
        XCTAssertEqual(insets.leading, Theme.Spacing.screen)
        XCTAssertEqual(insets.trailing, Theme.Spacing.screen)
        XCTAssertEqual(insets.top, 4)
        XCTAssertEqual(insets.bottom, 8)
    }

    func testPhoneLandscapeAddsSafeAreaToMargins() {
        let safe = UIEdgeInsets(top: 0, left: 59, bottom: 0, right: 59)
        let insets = ThawColumn.insets(containerWidth: 874, safeArea: safe)
        XCTAssertEqual(insets.leading, 59 + Theme.Spacing.screen)
        XCTAssertEqual(insets.trailing, 59 + Theme.Spacing.screen)
    }

    func testPadWidthCentresA700ptColumn() {
        let insets = ThawColumn.insets(containerWidth: 1032, safeArea: .zero)
        XCTAssertEqual(insets.leading, 166)
        XCTAssertEqual(1032 - insets.leading - insets.trailing, ThawColumn.maxWidth)
    }

    func testExtraInsetOnlyAppliesAboveTheColumn() {
        XCTAssertEqual(ThawColumn.extraInset(width: 402), 0)
        XCTAssertEqual(ThawColumn.extraInset(width: 700), 0)
        XCTAssertEqual(ThawColumn.extraInset(width: 1032), 166)
    }
}
