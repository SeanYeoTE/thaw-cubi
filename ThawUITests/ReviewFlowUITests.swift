import XCTest

/// End-to-end checks for the s12 flows: Payday review (Keep · Wait · Let go), Item detail (Let go, Decide now)
/// and the Add/Edit sheet. Real assertions only; screenshots live in PersonaTests.
final class ReviewFlowUITests: XCTestCase {
    var app: XCUIApplication!

    @MainActor func launch(_ fixture: String) {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-thawFixture", fixture]
        app.launch()
        app.finishOnboardingIfShown()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "tab bar missing")
    }

    @MainActor func all(_ id: String) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: id)
    }

    /// The system close button in the presented sheet's navigation bar.
    @MainActor var closeButton: XCUIElement {
        app.navigationBars.buttons.matching(NSPredicate(format: "label ==[c] %@ OR identifier ==[c] %@", "Close", "Close")).firstMatch
    }

    @MainActor func openFirstCard() {
        tapWhenReady(app.tab("Cooling"), "Cooling tab")
        tapWhenReady(all("home.card").firstMatch, "cooling card")
        XCTAssertTrue(all("detail.letGo").firstMatch.waitForExistence(timeout: 8), "item detail missing")
    }

    @MainActor func coolingCount() -> Int {
        tapWhenReady(app.tab("Cooling"), "Cooling tab")
        XCTAssertTrue(all("home.card").firstMatch.waitForExistence(timeout: 8), "no cooling cards")
        return all("home.card").count
    }

    // MARK: Payday review

    @MainActor func testPaydayShowsBudgetAndReviewRows() {
        launch("thawed")
        tapWhenReady(app.tab("Payday"), "Payday tab")
        XCTAssertTrue(all("payday.hero").firstMatch.waitForExistence(timeout: 8), "payday hero missing")
        XCTAssertTrue(all("payday.budget").firstMatch.exists, "payday budget block missing")
        XCTAssertTrue(all("payday.row").firstMatch.exists, "payday rows missing")
        tapWhenReady(all("payday.review").firstMatch, "Review button")
        XCTAssertTrue(all("review.meter").firstMatch.waitForExistence(timeout: 8), "review meter missing")
        XCTAssertGreaterThanOrEqual(all("review.row").count, 2)
        XCTAssertEqual(all("review.keep").count, all("review.row").count)
        XCTAssertEqual(all("review.wait").count, all("review.row").count)
        XCTAssertEqual(all("review.letGo").count, all("review.row").count)
    }

    @MainActor func testReviewKeepWaitLetGoAppliesChoices() {
        launch("thawed")
        let before = coolingCount()
        tapWhenReady(app.tab("Payday"), "Payday tab")
        tapWhenReady(all("payday.review").firstMatch, "Review button")
        XCTAssertTrue(all("review.row").firstMatch.waitForExistence(timeout: 8), "review rows missing")
        XCTAssertGreaterThanOrEqual(all("review.row").count, 3, "thawed fixture should have three wants")

        let done = all("review.done").firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 8), "review CTA missing")
        let initialCTA = done.label

        tapWhenReady(all("review.letGo").element(boundBy: 0), "Let go on row 1")
        XCTAssertNotEqual(done.label, initialCTA, "CTA did not reflect Let go")
        XCTAssertTrue(done.label.contains("Let go") || done.label.contains("let go"), "CTA: \(done.label)")
        tapWhenReady(all("review.wait").element(boundBy: 1), "Wait on row 2")
        tapWhenReady(all("review.keep").element(boundBy: 2), "Keep on row 3")
        tapWhenReady(done, "review CTA")

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "review did not dismiss")
        XCTAssertLessThan(coolingCount(), before, "Let go and Keep should leave Cooling")
    }

    @MainActor func testReviewCloseWithChangesAsksBeforeDiscarding() {
        launch("thawed")
        tapWhenReady(app.tab("Payday"), "Payday tab")
        tapWhenReady(all("payday.review").firstMatch, "Review button")
        tapWhenReady(all("review.letGo").firstMatch, "Let go on row 1")
        tapWhenReady(closeButton, "Close")
        tapWhenReady(app.descendants(matching: .any).matching(identifier: "Keep choosing").firstMatch, "Keep choosing")
        XCTAssertTrue(all("review.row").firstMatch.exists, "review should stay open")
        tapWhenReady(closeButton, "Close")
        tapWhenReady(app.descendants(matching: .any).matching(identifier: "Discard").firstMatch, "Discard")
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "review did not dismiss")
    }

    // MARK: Item detail

    @MainActor func testDetailLetGoConfirmRemovesWant() {
        launch("sprint1")
        let before = coolingCount()
        openFirstCard()
        tapWhenReady(all("detail.letGo").firstMatch, "Let go")
        tapWhenReady(app.alerts.buttons["Cancel"], "Cancel in confirm")
        XCTAssertTrue(all("detail.letGo").firstMatch.waitForExistence(timeout: 5), "cancel should keep the detail open")
        tapWhenReady(all("detail.letGo").firstMatch, "Let go")
        tapWhenReady(app.alerts.buttons["Let go"], "Let go in confirm")
        XCTAssertTrue(all("home.card").firstMatch.waitForExistence(timeout: 12), "did not return to Cooling")
        XCTAssertEqual(all("home.card").count, before - 1)
    }

    @MainActor func testDetailDecideNowOffersThreeChoices() {
        launch("sprint1")
        openFirstCard()
        tapWhenReady(all("detail.decide").firstMatch, "Decide now")
        for id in ["decide.letGo", "decide.buy", "decide.wait"] {
            XCTAssertTrue(all(id).firstMatch.waitForExistence(timeout: 8), "missing \(id)")
        }
        tapWhenReady(closeButton, "Close")
        XCTAssertTrue(all("detail.decide").firstMatch.waitForExistence(timeout: 8), "should return to detail")
    }

    @MainActor func testDetailDecideNowWaitReturnsToCooling() {
        launch("sprint1")
        let before = coolingCount()
        openFirstCard()
        tapWhenReady(all("detail.decide").firstMatch, "Decide now")
        tapWhenReady(all("decide.wait").firstMatch, "Wait a payday")
        XCTAssertTrue(all("home.card").firstMatch.waitForExistence(timeout: 12), "did not return to Cooling")
        XCTAssertEqual(all("home.card").count, before, "waiting keeps the want cooling")
    }

    // MARK: Add and Edit sheet

    @MainActor func testAddSheetShowsThawDateAndAddsWant() {
        launch("sprint1")
        let before = coolingCount()
        tapWhenReady(all("home.add").firstMatch, "Add button")
        let name = all("addwant.name").firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 8), "add sheet missing")
        name.tap(); name.typeText("UI test lamp")
        let price = all("addwant.price").firstMatch
        price.tap(); price.typeText("45")
        XCTAssertTrue(all("addwant.thaw").firstMatch.exists, "thaw date line missing")
        XCTAssertFalse(all("addwant.delete").firstMatch.isHittable, "Delete must not show when adding")
        tapWhenReady(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Add to Thaw")).firstMatch, "Add to Thaw")
        XCTAssertTrue(all("home.card").firstMatch.waitForExistence(timeout: 10), "did not return to Cooling")
        XCTAssertEqual(all("home.card").count, before + 1)
    }

    @MainActor func testEditSheetOffersDeleteForCoolingWant() {
        launch("sprint1")
        let before = coolingCount()
        openFirstCard()
        tapWhenReady(all("detail.edit").firstMatch, "Edit")
        XCTAssertTrue(all("addwant.name").firstMatch.waitForExistence(timeout: 8), "edit sheet missing")
        XCTAssertFalse(all("addwant.status").firstMatch.isHittable, "status applies to decided wants only")
        let delete = all("addwant.delete").firstMatch
        XCTAssertTrue(delete.exists, "Delete missing in edit")
        delete.tap()
        let confirm = app.alerts.buttons["Delete"].exists ? app.alerts.buttons["Delete"] : app.sheets.buttons["Delete"]
        tapWhenReady(confirm, "Delete confirm")
        XCTAssertTrue(all("home.card").firstMatch.waitForExistence(timeout: 12), "did not return to Cooling")
        XCTAssertEqual(all("home.card").count, before - 1)
    }
}
