import XCTest

/// Exploratory persona runs. Screenshots go to THAW_SHOT_DIR (default /tmp/thaw-shots) for App Store assets.
final class PersonaTests: XCTestCase {
    let dir = ProcessInfo.processInfo.environment["THAW_SHOT_DIR"] ?? "/tmp/thaw-shots"
    var app: XCUIApplication!
    var persona = ""
    var step = 0

    @MainActor func installAlertHandler() {
        _ = addUIInterruptionMonitor(withDescription: "System alert") { alert in
            for name in ["Allow", "OK", "Allow While Using App"] where alert.buttons[name].exists {
                alert.buttons[name].tap(); return true
            }
            return false
        }
    }

    @MainActor func launch(_ args: [String]) {
        continueAfterFailure = false
        installAlertHandler()
        app = XCUIApplication()
        app.launchArguments = args
        app.launch()
    }

    @MainActor func shot(_ name: String) {
        step += 1
        let base = "\(dir)/\(persona)/\(String(format: "%02d", step))-\(name)"
        try? FileManager.default.createDirectory(atPath: "\(dir)/\(persona)", withIntermediateDirectories: true)
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: base + ".png"))
        try? app.debugDescription.write(toFile: base + ".txt", atomically: true, encoding: .utf8)
    }

    @MainActor func button(_ label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch
    }

    @MainActor func tap(_ label: String, wait: TimeInterval = 8) {
        tapWhenReady(button(label), "button \(label)", timeout: wait)
    }

    @MainActor func tapID(_ id: String, label: String? = nil, wait: TimeInterval = 8) {
        tapWhenReady(app.element(id: id, label: label), "element \(id)", timeout: wait)
    }

    @MainActor func tapTab(_ name: String) { tapWhenReady(app.tab(name), "\(name) tab") }

    @MainActor func back() {
        let b = app.buttons["BackButton"]
        if b.waitForExistence(timeout: 3) { b.tap() } else { XCTFail("[\(persona)] missing back button") }
    }

    @MainActor func tapText(_ label: String) {
        let t = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", label)).firstMatch
        tapWhenReady(t, "text \(label)")
    }

    @MainActor var nameField: XCUIElement { app.element(id: "addwant.name") }
    @MainActor var priceField: XCUIElement { app.element(id: "addwant.price") }

    /// Opens the Add sheet from Cooling and types the fields.
    @MainActor func addWant(name: String, price: String, reason: String = "") {
        tapID("home.add", label: "Add a want")
        XCTAssertTrue(nameField.waitForExistence(timeout: 8), "[\(persona)] add sheet missing")
        nameField.tap(); nameField.typeText(name)
        if !price.isEmpty { type(price, into: priceField, "price field") }
        if !reason.isEmpty { type(reason, into: app.element(id: "addwant.reason"), "reason field") }
    }

    @MainActor func type(_ text: String, into field: XCUIElement, _ what: String) {
        XCTAssertTrue(field.waitForExistence(timeout: 8), "[\(persona)] \(what) missing")
        field.tap(); field.typeText(text)
    }

    /// Waits for the Add sheet to close after a valid submit.
    @MainActor func waitForSheetToClose() {
        XCTAssertTrue(nameField.waitForNonExistence(timeout: 8), "[\(persona)] add sheet did not close")
    }

    /// Waits for the app to settle (XCUITest waits for idle before resolving a query); for screenshots only.
    @MainActor func settle() {
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 2)
    }

    @MainActor func finishOnboarding() {
        let cont = button("Continue ·")
        XCTAssertTrue(cont.waitForExistence(timeout: 8), "[\(persona)] onboarding Continue button missing")
        cont.tap()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "[\(persona)] tab bar missing after onboarding")
    }

    @MainActor func waitForCoolingCard(_ name: String) {
        let card = app.element(id: "home.card")
        XCTAssertTrue(card.waitForExistence(timeout: 8), "[\(persona)] no cooling card")
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
            .waitForExistence(timeout: 8), "[\(persona)] cooling card \(name) missing")
    }

    // MARK: Careful

    @MainActor func testCarefulUser() {
        persona = "careful"
        launch(["-thawFixture", "sprint1"])
        shot("onboarding-payday")
        tap("Last working day"); shot("payday-last-working-day")
        tap("Same date every month")
        tapWhenReady(app.buttons["Increment"].firstMatch, "payday day stepper")
        shot("payday-adjusted")
        finishOnboarding()
        waitForCoolingCard("Mechanical keyboard"); shot("cooling-home")
        tapText("Mechanical keyboard")
        XCTAssertTrue(app.buttons["BackButton"].waitForExistence(timeout: 8), "item detail did not open")
        shot("item-detail-payday-wait")
        back()
        // Needs re-check after U4 (Add/Edit sheet rework).
        addWant(name: "Film camera", price: "250", reason: "Want to take photos on my trip")
        shot("add-want-filled")
        tap("Add to Thaw")
        waitForSheetToClose()
        waitForCoolingCard("Film camera"); shot("cooling-with-new-want")
        tapText("Film camera")
        XCTAssertTrue(app.buttons["BackButton"].waitForExistence(timeout: 8), "new want detail did not open")
        shot("item-detail")
        back()
        tapTab("Stats"); XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 8)); shot("stats-empty")
        tapTab("Settings")
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 8), "Settings title missing"); shot("settings")
        tapTab("Cooling")
        XCTAssertTrue(app.element(id: "home.add").waitForExistence(timeout: 8), "Cooling did not return")
    }

    /// Needs re-check after U1 (Payday budget block) and U2 (Keep, Wait, Let go review rows).
    @MainActor func testCarefulPaydayReview() {
        persona = "careful-review"
        launch(["-thawFixture", "thawed"])
        XCTAssertTrue(app.element(id: "home.card").waitForExistence(timeout: 8), "thawed fixture shows no cards")
        shot("home-thawed")
        tapTab("Payday")
        XCTAssertTrue(app.element(id: "payday.hero").waitForExistence(timeout: 8), "payday hero missing")
        shot("payday-ready")
        tapID("payday.review", label: "Review"); shot("payday-review")
        // U2 target: per-row Keep, Wait, Let go buttons.
        let rows = app.descendants(matching: .any).matching(identifier: "review.row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 8), "review rows missing")
        XCTAssertGreaterThanOrEqual(rows.count, 2, "thawed fixture should list several wants to review")
        tapID("review.wait"); shot("review-wait-one")
        tapID("review.keep"); shot("review-keep-one")
        tapID("review.done")
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "review did not dismiss")
        shot("after-review")
        tapTab("Stats"); shot("stats-after-review")
    }

    // MARK: Lazy

    @MainActor func testLazyUser() {
        persona = "lazy"
        launch(["-thawReset"])
        shot("fresh-launch")
        finishOnboarding()
        XCTAssertTrue(app.element(id: "home.empty").waitForExistence(timeout: 8), "empty state missing")
        shot("home-empty")
        addWant(name: "Sneakers", price: "")
        shot("add-want-no-price")
        tap("Add to Thaw")
        // A want needs a price: the sheet stays open with an error until one is entered.
        let error = app.staticTexts["Enter a price above S$0."]
        XCTAssertTrue(error.waitForExistence(timeout: 8), "[\(persona)] missing-price error not shown")
        XCTAssertTrue(nameField.exists, "[\(persona)] sheet should stay open without a price")
        shot("after-add-no-price")
        type("120", into: priceField, "price field")
        tap("Add to Thaw")
        waitForSheetToClose()
        waitForCoolingCard("Sneakers"); shot("home-one-want")
        tapTab("Stats"); shot("stats")
        tapTab("Settings"); shot("settings")
    }

    // MARK: Hardcore

    @MainActor func testHardcoreUser() {
        persona = "hardcore"
        launch(["-thawFixture", "history"])
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "history fixture should skip onboarding")
        shot("launch-with-history")
        tapID("home.add", label: "Add a want")
        XCTAssertTrue(nameField.waitForExistence(timeout: 8), "[\(persona)] add sheet missing")
        tap("Add to Thaw")
        XCTAssertTrue(app.staticTexts["Add a name for the item."].waitForExistence(timeout: 8),
                      "[\(persona)] empty submit should show the name error")
        XCTAssertTrue(nameField.exists, "[\(persona)] empty submit should keep the sheet open")
        shot("empty-submit")
        nameField.tap()
        nameField.typeText(String(repeating: "Supercalifragilistic 🔥 ", count: 12))
        type("99999999999999999999", into: priceField, "price field")
        shot("absurd-inputs")
        tap("Add to Thaw")
        // Exploratory from here: outcomes of absurd input are not yet specified. Wait for the sheet to either
        // close or show an error, instead of sleeping, then branch on the settled state.
        let closed = NSPredicate(format: "exists == false")
        let sheetClosed = XCTNSPredicateExpectation(predicate: closed, object: nameField)
        let anyError = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true"),
                                                 object: app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@ OR label BEGINSWITH %@", "Enter a price", "Add a name")).firstMatch)
        _ = XCTWaiter.wait(for: [sheetClosed, anyError], timeout: 8, enforceOrder: false)
        shot("absurd-submitted")
        if nameField.exists {
            priceField.tap()
            priceField.typeText("-5abc!@#")
            shot("negative-price")
            tap("Add to Thaw"); settle(); shot("negative-price-submitted")
        }
        if nameField.exists {
            // A sheet with input asks before discarding, whether swiped down or closed.
            app.swipeDown()
            let discard = app.dialogButton("Discard")
            if !discard.waitForExistence(timeout: 3) {
                tapWhenReady(app.navigationBars.buttons["Cancel"].firstMatch, "Add sheet Cancel button")
            }
            XCTAssertTrue(discard.waitForExistence(timeout: 8), "[\(persona)] discard confirmation missing")
            shot("discard-confirmation")
            discard.tap()
            XCTAssertTrue(nameField.waitForNonExistence(timeout: 8), "[\(persona)] add sheet did not close after Discard")
        }
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 8), "tab bar missing after sheet")
        for _ in 0..<15 { for t in ["Stats", "Settings", "Cooling"] where app.tab(t).exists { app.tab(t).tap() } }
        shot("after-tab-mashing")
        tapTab("Stats"); shot("stats-with-history")
        app.swipeUp(); shot("stats-scrolled")
        tapTab("Settings")
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 8), "Settings missing")
        for _ in 0..<25 { for b in app.buttons.matching(identifier: "Increment").allElementsBoundByIndex { b.tapIfExists() } }
        shot("settings-maxed")
        for _ in 0..<40 { for b in app.buttons.matching(identifier: "Decrement").allElementsBoundByIndex { b.tapIfExists() } }
        shot("settings-minned")
        XCUIDevice.shared.orientation = .landscapeLeft; settle(); shot("landscape-settings")
        tapTab("Cooling"); shot("landscape-home")
        XCUIDevice.shared.orientation = .portrait; settle()
        app.terminate(); app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "relaunch did not reach tabs (persistence)")
        shot("relaunch-persisted")
    }
}

extension XCUIElement {
    @MainActor func tapIfExists() { if exists && isHittable { tap() } }
}
