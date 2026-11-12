import XCTest

/// Accessibility audit for the screens added in s12: Item detail, Payday review, Still want it, Add sheet and
/// the Payday tab with its budget block. Each runs at the default and an accessibility text size.
/// Findings are failures so each can be assigned to an owner. No exclusions are used.
final class NewScreensAuditTests: XCTestCase {
    var app: XCUIApplication!

    @MainActor func launch(fixture: String, large: Bool) {
        continueAfterFailure = true
        app = XCUIApplication()
        var args = ["-thawFixture", fixture]
        if large { args += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launchArguments = args
        app.launch()
        app.finishOnboardingIfShown()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "tab bar missing")
    }

    @MainActor func el(_ id: String) -> XCUIElement { app.element(id: id) }

    @MainActor func run(_ screen: String, fixture: String = "thawed", navigate: () -> Void) {
        for large in [false, true] {
            launch(fixture: fixture, large: large)
            navigate()
            do {
                try app.performAccessibilityAudit { issue in
                    // Log the element so each finding can be traced to a view; nothing is excluded.
                    let e = issue.element
                    print("AUDITISSUE [\(screen) \(large ? "AXL" : "default")] \(issue.auditType.rawValue) | \(issue.compactDescription) | id=\(e?.identifier ?? "-") type=\(e?.elementType.rawValue ?? 0) label=\(e?.label ?? "-")")
                    return false
                }
            } catch {
                XCTFail("[\(screen) \(large ? "AXL" : "default")] \(error)")
            }
            app.terminate()
        }
    }

    @MainActor func openDetail() {
        tapWhenReady(app.tab("Cooling"), "Cooling tab")
        tapWhenReady(el("home.card"), "cooling card")
        XCTAssertTrue(el("detail.letGo").waitForExistence(timeout: 8), "detail missing")
    }

    @MainActor func testPaydayBudgetAudit() {
        run("Payday budget") {
            tapWhenReady(app.tab("Payday"), "Payday tab")
            XCTAssertTrue(el("payday.budget").waitForExistence(timeout: 8))
        }
    }

    @MainActor func testItemDetailAudit() { run("Item detail") { openDetail() } }

    @MainActor func testPaydayReviewAudit() {
        run("Payday review") {
            tapWhenReady(app.tab("Payday"), "Payday tab")
            tapWhenReady(el("payday.review"), "Review button")
            XCTAssertTrue(el("review.row").waitForExistence(timeout: 8))
        }
    }

    @MainActor func testStillWantItAudit() {
        run("Still want it") {
            openDetail()
            tapWhenReady(el("detail.decide"), "Decide now")
            XCTAssertTrue(el("decide.letGo").waitForExistence(timeout: 8))
        }
    }

    @MainActor func testAddSheetAudit() {
        run("Add sheet") {
            tapWhenReady(app.tab("Cooling"), "Cooling tab")
            tapWhenReady(el("home.add"), "Add button")
            XCTAssertTrue(el("addwant.name").waitForExistence(timeout: 8))
        }
    }
}
