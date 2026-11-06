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
        continueAfterFailure = true
        installAlertHandler()
        app = XCUIApplication()
        app.launchArguments = args
        app.launch()
        sleep(1)
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

    @MainActor func tap(_ label: String, wait: TimeInterval = 3) {
        let b = button(label)
        if b.waitForExistence(timeout: wait) { b.tap() } else { XCTFail("[\(persona)] missing button \(label)") }
        usleep(600_000)
    }

    @MainActor func back() {
        if app.buttons["BackButton"].exists { app.buttons["BackButton"].tap() }
        usleep(600_000)
    }

    @MainActor func tapText(_ label: String) {
        let t = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", label)).firstMatch
        if t.waitForExistence(timeout: 3) { t.tap() } else { XCTFail("[\(persona)] missing text \(label)") }
        usleep(600_000)
    }

    @MainActor func addWant(name: String, price: String, reason: String = "") {
        tap("Add a want")
        let fields = app.textFields
        if fields.count > 0 {
            fields.element(boundBy: 0).tap(); fields.element(boundBy: 0).typeText(name)
            if fields.count > 1, !price.isEmpty { fields.element(boundBy: 1).tap(); fields.element(boundBy: 1).typeText(price) }
        }
        if !reason.isEmpty, app.textViews.count > 0 {
            app.textViews.element(boundBy: 0).tap(); app.textViews.element(boundBy: 0).typeText(reason)
        }
    }

    @MainActor func finishOnboarding() {
        guard button("Save ·").waitForExistence(timeout: 2) else { return }
        tap("Save ·")
        sleep(1)
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
        shot("cooling-home")
        tapText("Mechanical keyboard"); sleep(1); shot("item-detail-payday-wait")
        back()
        addWant(name: "Film camera", price: "250", reason: "Want to take photos on my trip")
        shot("add-want-filled")
        tap("Add to Thaw"); sleep(1)
        shot("cooling-with-new-want")
        tapText("Film camera"); sleep(1); shot("item-detail")
        back(); sleep(1)
        tap("Saved"); shot("saved-empty")
        tap("Settings"); shot("settings")
        tap("Cooling")
    }

    @MainActor func testCarefulPaydayReview() {
        persona = "careful-review"
        launch(["-thawFixture", "thawed"])
        shot("home-thawed")
        tapText("Next payday"); sleep(1); shot("payday-preview")
        tap("Review now"); sleep(1); shot("payday-review")
        tap("Waiting on Linen"); shot("review-keep-two")
        tap("Waiting on Espresso"); shot("review-over-budget")
        tap("Keeping Espresso")
        tap("Keep 2"); sleep(2); shot("after-review")
        tap("Saved"); shot("saved-after-review")
    }

    // MARK: Lazy

    @MainActor func testLazyUser() {
        persona = "lazy"
        launch(["-thawReset"])
        shot("fresh-launch")
        finishOnboarding()
        shot("home-empty")
        addWant(name: "Sneakers", price: "")
        shot("add-want-no-price")
        tap("Add to Thaw"); sleep(1)
        shot("after-add-no-price")
        if app.buttons["Keep editing"].exists || app.alerts.count > 0 { shot("alert") }
        if app.navigationBars["Add to Thaw"].exists || app.textFields.count > 0 {
            app.textFields.element(boundBy: 1).tap(); app.textFields.element(boundBy: 1).typeText("120")
            tap("Add to Thaw"); sleep(1)
        }
        shot("home-one-want")
        tap("Saved"); shot("saved")
        tap("Settings"); shot("settings")
    }

    // MARK: Hardcore

    @MainActor func testHardcoreUser() {
        persona = "hardcore"
        launch(["-thawFixture", "history"])
        shot("launch-with-history")
        finishOnboarding()
        shot("home")
        tap("Add a want")
        tap("Add to Thaw"); sleep(1); shot("empty-submit")
        app.textFields.element(boundBy: 0).tap()
        app.textFields.element(boundBy: 0).typeText(String(repeating: "Supercalifragilistic 🔥 ", count: 12))
        app.textFields.element(boundBy: 1).tap()
        app.textFields.element(boundBy: 1).typeText("99999999999999999999")
        shot("absurd-inputs")
        tap("Add to Thaw"); sleep(1); shot("absurd-submitted")
        if app.alerts.count > 0 { app.alerts.buttons.firstMatch.tap() }
        if app.textFields.count > 0 {
            app.textFields.element(boundBy: 1).tap()
            app.textFields.element(boundBy: 1).typeText("-5abc!@#")
            shot("negative-price")
            tap("Add to Thaw"); sleep(1); shot("negative-price-submitted")
        }
        // cancel/discard path
        if app.textFields.count > 0 { app.swipeDown(); sleep(1); shot("swipe-dismiss-attempt")
            if app.alerts.count > 0 { shot("discard-alert"); app.alerts.buttons["Discard"].tap() } }
        // hammer tabs
        for _ in 0..<15 { for t in ["Saved", "Settings", "Cooling"] where button(t).exists { button(t).tap() } }
        shot("after-tab-mashing")
        tap("Saved"); shot("saved-with-history")
        app.swipeUp(); shot("saved-scrolled")
        tap("Settings")
        for _ in 0..<25 { for b in app.buttons.matching(identifier: "Increment").allElementsBoundByIndex { b.tapIfExists() } }
        shot("settings-maxed")
        for _ in 0..<40 { for b in app.buttons.matching(identifier: "Decrement").allElementsBoundByIndex { b.tapIfExists() } }
        shot("settings-minned")
        XCUIDevice.shared.orientation = .landscapeLeft; sleep(1); shot("landscape-settings")
        tap("Cooling"); shot("landscape-home")
        XCUIDevice.shared.orientation = .portrait; sleep(1)
        app.terminate(); app.launch(); sleep(1); shot("relaunch-persisted")
    }
}

extension XCUIElement {
    @MainActor func tapIfExists() { if exists && isHittable { tap() } }
}
