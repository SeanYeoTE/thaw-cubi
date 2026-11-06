import XCTest
@testable import Thaw

/// Real file-backed store, interactor and presenter; only the view and notification scheduler are fakes.
@MainActor
final class IntegrationSavedTests: XCTestCase {
    private final class FakeView: SavedViewProtocol {
        var models: [SavedViewModel] = []
        var model: SavedViewModel? { models.last }
        func render(_ model: SavedViewModel) { models.append(model) }
        func showDecisionOptions(id: UUID, sheet: SavedDecisionSheet) {}
        func showDeleteConfirmation(id: UUID, confirmation: SavedDeleteConfirmation) {}
    }

    private final class FakeRouter: SavedRouterProtocol {}

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

    func testSavedFollowsSkipReopenAndBuy() throws {
        let fileURL = try makeFileURL()
        let store = WantStore(fileURL: fileURL)
        store.save(settings: .default)
        store.add(name: "Grinder", price: 420, reason: "Better coffee")
        store.add(name: "Keyboard", price: 189, reason: "Clicky")
        let grinder = try XCTUnwrap(store.wants.first { $0.name == "Grinder" })
        let keyboard = try XCTUnwrap(store.wants.first { $0.name == "Keyboard" })

        let view = FakeView()
        let interactor = SavedInteractor(store: store, reminders: Reminders(store: store) { _ in SilentScheduler() })
        let presenter = SavedPresenter(view: view, interactor: interactor, router: FakeRouter())
        presenter.viewWillAppear()
        XCTAssertEqual(view.model?.savedText, Formatting.sgd(0))
        XCTAssertEqual(view.model?.history, [])

        // Skip elsewhere in the app: the store changes and DataChange is posted.
        store.update(grinder.id, status: .skipped)
        DataChange.post()
        XCTAssertEqual(view.models.count, 2)
        XCTAssertEqual(view.model?.savedText, Formatting.sgd(420))
        XCTAssertEqual(view.model?.history.map(\.name), ["Grinder"])
        XCTAssertEqual(view.model?.history.first?.outcome, "Skipped")

        // Undo from Saved: it leaves History and the total.
        presenter.chooseDecisionOption(id: grinder.id, option: .moveBackToCooling)
        XCTAssertEqual(view.model?.history, [])
        XCTAssertEqual(view.model?.savedText, Formatting.sgd(0))
        XCTAssertEqual(store.want(id: grinder.id)?.status, .cooling)
        XCTAssertEqual(store.want(id: grinder.id)?.thawsAt, grinder.thawsAt)

        // Skip again, then buy the other one: History shows "Bought" and the total stays.
        store.update(grinder.id, status: .skipped)
        DataChange.post()
        let totalBeforeBuying = view.model?.savedText
        store.decide(id: keyboard.id, keep: true)
        DataChange.post()
        XCTAssertEqual(view.model?.savedText, totalBeforeBuying)
        XCTAssertEqual(view.model?.history.first { $0.name == "Keyboard" }?.outcome, "Bought")
        XCTAssertEqual(Set(view.model?.history.map(\.name) ?? []), ["Grinder", "Keyboard"])

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
        let interactor = SavedInteractor(store: store, reminders: Reminders(store: store) { _ in SilentScheduler() })
        let presenter = SavedPresenter(view: view, interactor: interactor, router: FakeRouter())
        presenter.viewWillAppear()
        XCTAssertEqual(view.model?.savedText, Formatting.sgd(69))

        presenter.chooseDecisionOption(id: shirt.id, option: .markBought)
        XCTAssertEqual(view.model?.history.first?.outcome, "Bought")
        XCTAssertEqual(view.model?.savedText, Formatting.sgd(0))

        presenter.confirmDelete(id: shirt.id)
        XCTAssertEqual(view.model?.history, [])
        XCTAssertNil(WantStore(fileURL: fileURL).want(id: shirt.id))
    }
}
