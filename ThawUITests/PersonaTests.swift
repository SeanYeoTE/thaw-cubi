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

    /// Opens the Add sheet from Cooling and types the fields. Needs re-check after U4 (new Add/Edit sheet).
    @MainActor func addWant(name: String, price: String, reason: String = "") {
        tapID("home.add", label: "Add a want")
        let fields = app.textFields
        XCTAssertTrue(fields.element(boundBy: 0).waitForExistence(timeout: 8), "[\(persona)] add sheet missing")
        fields.element(boundBy: 0).tap(); fields.element(boundBy: 0).typeText(name)
        if !price.isEmpty {
            XCTAssertGreaterThan(fields.count, 1, "[\(persona)] price field missing")
            fields.element(boundBy: 1).tap(); fields.element(boundBy: 1).typeText(price)
        }
        if !reason.isEmpty, app.textViews.count > 0 {
            app.textViews.element(boundBy: 0).tap(); app.textViews.element(boundBy: 0).typeText(reason)
        }
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
        app.buttons["Increment"].firstMatch.tapIfExists()
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
        let done = app.element(id: "review.done")
        let cta = done.exists ? done : button("Keep")
        tapWhenReady(cta, "review confirm button")
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
        // Exploratory: a want without a price may prompt or be rejected.
        sleep(1); shot("after-add-no-price")
        if app.textFields.count > 1 {
            app.textFields.element(boundBy: 1).tap(); app.textFields.element(boundBy: 1).typeText("120")
            tap("Add to Thaw")
        }
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
        tap("Add to Thaw"); shot("empty-submit")
        XCTAssertTrue(app.textFields.firstMatch.exists, "empty submit should keep the sheet open")
        app.textFields.element(boundBy: 0).tap()
        app.textFields.element(boundBy: 0).typeText(String(repeating: "Supercalifragilistic 🔥 ", count: 12))
        app.textFields.element(boundBy: 1).tap()
        app.textFields.element(boundBy: 1).typeText("99999999999999999999")
        shot("absurd-inputs")
        tap("Add to Thaw"); sleep(1); shot("absurd-submitted")
        // Exploratory from here: outcomes of absurd input are not yet specified.
        if app.alerts.count > 0 { app.alerts.buttons.firstMatch.tap() }
        if app.textFields.count > 1 {
            app.textFields.element(boundBy: 1).tap()
            app.textFields.element(boundBy: 1).typeText("-5abc!@#")
            shot("negative-price")
            tap("Add to Thaw"); sleep(1); shot("negative-price-submitted")
        }
        if app.textFields.count > 0 {
            app.swipeDown(); sleep(1); shot("swipe-dismiss-attempt")
            if app.alerts.count > 0 { shot("discard-alert"); app.alerts.buttons["Discard"].tap() }
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
        XCUIDevice.shared.orientation = .landscapeLeft; sleep(1); shot("landscape-settings")
        tapTab("Cooling"); shot("landscape-home")
        XCUIDevice.shared.orientation = .portrait; sleep(1)
        app.terminate(); app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "relaunch did not reach tabs (persistence)")
        shot("relaunch-persisted")
    }
}

extension XCUIElement {
    @MainActor func tapIfExists() { if exists && isHittable { tap() } }
}
