import XCTest
@testable import Thaw

/// Real file-backed store, interactor and presenter; only the view and notification scheduler are fakes.
@MainActor
final class IntegrationSavedTests: XCTestCase {
    private final class FakeView: SavedViewProtocol {
        var models: [SavedViewModel] = []
        var model: SavedViewModel? { models.last }
        func render(_ model: SavedViewModel) { models.append(model) }
        func showDeleteConfirmation(id: UUID, confirmation: SavedDeleteConfirmation) {}
        func showChipExplanation(_ explanation: SavedChipExplanation) {}
    }

    private final class FakeRouter: SavedRouterProtocol {
        func showEdit(id: UUID) {}
    }

    private struct SilentScheduler: NotificationScheduling {
        func requestAuthorizationIfNeeded() async -> Bool { false }
        func schedulePaydayReview(at: Date, thawingCount: Int, total: Decimal) async {}
        func scheduleTimerThaw(wantID: UUID, name: String, at: Date) async {}
        func scheduleReminder(at: Date, thawingCount: Int, total: Decimal) async {}
        func cancelAll() async {}
    }

    /// A fresh state file in its own temp directory, removed after the test.
    private func makeFileURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("IntegrationSaved-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory.appendingPathComponent("state.json")
    }

    /// A private defaults suite, so stored filters don't leak between tests or into the app.
    private func makeDefaults() throws -> UserDefaults {
        let name = "IntegrationSaved-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        addTeardownBlock { UserDefaults().removePersistentDomain(forName: name) }
        return defaults
    }

    private func makeInteractor(_ store: WantStore, defaults: UserDefaults) -> SavedInteractor {
        SavedInteractor(store: store, reminders: Reminders(store: store) { _ in SilentScheduler() }, defaults: defaults)
    }

    func testSavedFollowsSkipReopenAndBuy() throws {
        let fileURL = try makeFileURL()
        let store = WantStore(fileURL: fileURL)
        store.save(settings: .default)
        store.add(name: "Grinder", price: 420, reason: "Better coffee")
        store.add(name: "Keyboard", price: 189, reason: "Clicky")
        let grinder = try XCTUnwrap(store.wants.first { $0.name == "Grinder" })
        let keyboard = try XCTUnwrap(store.wants.first { $0.name == "Keyboard" })

        let view = FakeView()
        let interactor = makeInteractor(store, defaults: try makeDefaults())
        let presenter = SavedPresenter(view: view, interactor: interactor, router: FakeRouter())
        presenter.viewWillAppear()
        XCTAssertEqual(view.model?.hero.savedText, Formatting.sgd(0))
        XCTAssertNil(view.model?.history)
        XCTAssertNotNil(view.model?.empty)

        // Skip elsewhere in the app: the store changes and DataChange is posted.
        store.update(grinder.id, status: .skipped)
        DataChange.post()
        XCTAssertEqual(view.models.count, 2)
        XCTAssertEqual(view.model?.hero.savedText, Formatting.sgd(420))
        XCTAssertEqual(view.model?.history?.rows.map(\.name), ["Grinder"])
        XCTAssertEqual(view.model?.history?.rows.first?.isSkipped, true)
        XCTAssertEqual(view.model?.history?.sections.first?.detail, "S$420 saved")

        // Undo from Saved: it leaves History and the total.
        store.reopen(grinder.id)
        DataChange.post()
        XCTAssertNil(view.model?.history)
        XCTAssertNotNil(view.model?.empty)
        XCTAssertEqual(view.model?.hero.savedText, Formatting.sgd(0))
        XCTAssertEqual(store.want(id: grinder.id)?.status, .cooling)
        XCTAssertEqual(store.want(id: grinder.id)?.thawsAt, grinder.thawsAt)

        // Skip again, then buy the other one: History shows "Bought" and the total stays.
        store.update(grinder.id, status: .skipped)
        DataChange.post()
        let totalBeforeBuying = view.model?.hero.savedText
        store.decide(id: keyboard.id, keep: true)
        DataChange.post()
        XCTAssertEqual(view.model?.hero.savedText, totalBeforeBuying)
        XCTAssertEqual(view.model?.history?.rows.first { $0.name == "Keyboard" }?.isSkipped, false)
        XCTAssertTrue(view.model?.history?.rows.first { $0.name == "Keyboard" }?.accessibilityValue.hasPrefix("Bought, decided ") ?? false)
        XCTAssertEqual(Set(view.model?.history?.rows.map(\.name) ?? []), ["Grinder", "Keyboard"])

        // The changes were persisted.
        let reloaded = WantStore(fileURL: fileURL)
        XCTAssertEqual(reloaded.want(id: grinder.id)?.status, .skipped)
        XCTAssertEqual(reloaded.want(id: keyboard.id)?.status, .bought)
    }

    func testEditAndDeleteFromSavedReachTheStore() throws {
        let fileURL = try makeFileURL()
        let store = WantStore(fileURL: fileURL)
        store.save(settings: .default)
        store.add(name: "Shirt", price: 69, reason: "Nice")
        let shirt = try XCTUnwrap(store.wants.first)
        store.update(shirt.id, status: .skipped)

        let view = FakeView()
        let interactor = makeInteractor(store, defaults: try makeDefaults())
        let presenter = SavedPresenter(view: view, interactor: interactor, router: FakeRouter())
        presenter.viewWillAppear()
        XCTAssertEqual(view.model?.hero.savedText, Formatting.sgd(69))

        store.setDecision(shirt.id, to: .bought)
        DataChange.post()
        XCTAssertEqual(view.model?.history?.rows.first?.isSkipped, false)
        XCTAssertEqual(view.model?.hero.savedText, Formatting.sgd(0))

        presenter.confirmDelete(id: shirt.id)
        XCTAssertNil(view.model?.history)
        XCTAssertNotNil(view.model?.empty)
        XCTAssertNil(WantStore(fileURL: fileURL).want(id: shirt.id))
    }

    func testFilterAndRangeSurviveRelaunch() throws {
        let store = WantStore(fileURL: try makeFileURL())
        let defaults = try makeDefaults()
        let first = makeInteractor(store, defaults: defaults)
        XCTAssertEqual(first.historyFilter, .all)
        XCTAssertEqual(first.chartRange, .sixMonths)
        let presenter = SavedPresenter(view: FakeView(), interactor: first, router: FakeRouter())
        presenter.selectHistoryFilter(at: 2)
        presenter.selectChartRange(at: 1)
        XCTAssertEqual(defaults.string(forKey: "stats.historyFilter"), "bought")
        XCTAssertEqual(defaults.string(forKey: "stats.chartRange"), "oneYear")

        let relaunched = makeInteractor(store, defaults: defaults)
        XCTAssertEqual(relaunched.historyFilter, .bought)
        XCTAssertEqual(relaunched.chartRange, .oneYear)

        defaults.set("unknown", forKey: "stats.historyFilter")
        XCTAssertEqual(relaunched.historyFilter, .all)
    }
}
