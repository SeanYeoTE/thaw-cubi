import XCTest

/// Apple's automated accessibility audit, run for each screen at the default and an accessibility text size.
/// Findings are reported as test failures so each can be assigned to a screen owner.
/// Light mode only, and decorative Theme.border card edges are under 3:1 by design (s12 decisions), so
/// contrast findings on those edges are the only intended exclusion; none are needed until a run shows one.
final class AccessibilityAuditTests: XCTestCase {
    var app: XCUIApplication!

    @MainActor func launch(fixture: String, accessibilitySize: Bool) {
        continueAfterFailure = true
        app = XCUIApplication()
        var args = ["-thawFixture", fixture]
        if accessibilitySize { args += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launchArguments = args
        app.launch()
        app.finishOnboardingIfShown()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "tab bar missing")
    }

    @MainActor func audit(_ screen: String) {
        do {
            try app.performAccessibilityAudit { issue in
                // Add narrowly scoped exclusions here, each with a comment saying why. Never a whole category.
                _ = issue
                return false
            }
        } catch {
            XCTFail("[\(screen)] audit failed to run: \(error)")
        }
    }

    @MainActor func goTo(_ tab: String) {
        tapWhenReady(app.tab(tab), "\(tab) tab")
    }

    @MainActor func openEditSheet() {
        goTo("Cooling")
        tapWhenReady(app.element(id: "home.card"), "cooling card")
        tapWhenReady(app.element(id: "detail.edit", label: "Edit"), "Edit button")
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 8), "edit sheet fields missing")
    }

    @MainActor func openPaydayRule() {
        goTo("Settings")
        let row = app.collectionViews.cells.matching(NSPredicate(format: "label BEGINSWITH %@", "Payday")).firstMatch
        tapWhenReady(row, "Payday rule row")
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Same date")).firstMatch.waitForExistence(timeout: 8), "payday rule screen missing")
    }

    @MainActor func run(_ screen: String, fixture: String = "thawed", navigate: () -> Void) {
        for large in [false, true] {
            launch(fixture: fixture, accessibilitySize: large)
            navigate()
            audit("\(screen) \(large ? "AXL" : "default")")
            app.terminate()
        }
    }

    @MainActor func testCoolingAudit() {
        run("Cooling") { goTo("Cooling"); XCTAssertTrue(app.element(id: "home.card").waitForExistence(timeout: 8)) }
    }

    @MainActor func testPaydayAudit() {
        run("Payday") { goTo("Payday"); XCTAssertTrue(app.element(id: "payday.hero").waitForExistence(timeout: 8)) }
    }

    @MainActor func testStatsAudit() {
        run("Stats", fixture: "history") { goTo("Stats") }
    }

    @MainActor func testSettingsAudit() {
        run("Settings") { goTo("Settings") }
    }

    @MainActor func testEditSheetAudit() {
        run("Edit sheet") { openEditSheet() }
    }

    @MainActor func testPaydayRuleAudit() {
        run("Payday rule") { openPaydayRule() }
    }
}
