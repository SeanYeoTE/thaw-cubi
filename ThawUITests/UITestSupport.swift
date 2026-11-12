import XCTest

/// Shared helpers for the UI tests. Everything waits for existence instead of sleeping.
extension XCUIApplication {
    /// First element with the identifier, else the first button or text whose label starts with `label`.
    @MainActor func element(id: String, label: String? = nil) -> XCUIElement {
        let byID = descendants(matching: .any).matching(identifier: id).firstMatch
        guard let label else { return byID }
        if byID.exists { return byID }
        let predicate = NSPredicate(format: "label BEGINSWITH %@", label)
        let byLabel = buttons.matching(predicate).firstMatch
        return byLabel.exists ? byLabel : descendants(matching: .any).matching(predicate).firstMatch
    }

    @MainActor func tab(_ name: String) -> XCUIElement {
        tabBars.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
    }

    /// Dismisses onboarding when present (fixtures without settings start there).
    @MainActor func finishOnboardingIfShown() {
        let cont = buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Continue ·")).firstMatch
        guard cont.waitForExistence(timeout: 3) else { return }
        cont.tap()
    }
}

extension XCTestCase {
    /// Waits for the element, fails the test if it never appears, then taps it.
    @MainActor @discardableResult
    func tapWhenReady(_ element: XCUIElement, _ what: String, timeout: TimeInterval = 8,
                      file: StaticString = #filePath, line: UInt = #line) -> Bool {
        guard element.waitForExistence(timeout: timeout) else {
            XCTFail("missing \(what)", file: file, line: line)
            return false
        }
        element.tap()
        return true
    }
}
