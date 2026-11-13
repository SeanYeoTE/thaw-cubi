import XCTest
@testable import Thaw

/// Real file-backed store, interactor and presenter for the Payday review; only the view, router and
/// notification scheduler are fakes.
@MainActor
final class IntegrationReviewTests: XCTestCase {
    private final class FakeView: PaydayReviewViewProtocol {
        var content: PaydayReviewContent?
        var summaries: [PaydayReviewSummary] = []
        func render(_ content: PaydayReviewContent) { self.content = content }
        func update(_ summary: PaydayReviewSummary, animated: Bool) { summaries.append(summary) }
        func showDiscardConfirmation() {}
        func playSuccessFeedback() {}
        func setCTAEnabled(_ enabled: Bool) {}
    }

    private final class FakeRouter: PaydayReviewRouterProtocol {
        var dismissed = 0
        func dismiss() { dismissed += 1 }
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
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("IntegrationReview-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory.appendingPathComponent("state.json")
    }

    func testReviewAppliesEachChoiceOnceEvenWhenDoneIsTappedTwice() throws {
        let fileURL = try makeFileURL()
        let store = WantStore(fileURL: fileURL)
        store.save(settings: .default)
        let now = Date.now
        // Frozen long enough ago that every want has thawed, a month or more apart so each thaws on a different payday.
        store.add(name: "Keyboard", price: 189, reason: "Clicky", frozenOn: now.addingTimeInterval(-86_400 * 130))
        store.add(name: "Grinder", price: 420, reason: "Coffee", frozenOn: now.addingTimeInterval(-86_400 * 95))
        store.add(name: "Shirt", price: 69, reason: "Hot", frozenOn: now.addingTimeInterval(-86_400 * 60))
        store.add(name: "Case", price: 24, reason: "Cracked", frozenOn: now.addingTimeInterval(-86_400 * 10))
        let wants = store.reviewQueue
        XCTAssertEqual(wants.count, 4)
        let keyboard = try XCTUnwrap(wants.first { $0.name == "Keyboard" })
        let grinder = try XCTUnwrap(wants.first { $0.name == "Grinder" })
        let shirt = try XCTUnwrap(wants.first { $0.name == "Shirt" })
        let quick = try XCTUnwrap(wants.first { $0.name == "Case" })

        let view = FakeView(), router = FakeRouter()
        let reminders = Reminders(store: store) { _ in SilentScheduler() }
        let interactor = PaydayReviewInteractor(store: store, reminders: reminders, wants: wants)
        let presenter = PaydayReviewPresenter(view: view, interactor: interactor, router: router, onFinish: nil)
        presenter.viewDidLoad()
        // Best fit in thaw order; the quick thaw sits in its own group and doesn't count.
        XCTAssertEqual(view.content?.rows.map(\.id), [keyboard.id, grinder.id, shirt.id])
        XCTAssertEqual(view.content?.rows.map(\.choice), [.keep, .wait, .keep])
        XCTAssertEqual(view.content?.quickRows.map(\.id), [quick.id])
        XCTAssertEqual(view.summaries.last?.statusText, "S$42 left")

        presenter.setChoice(id: shirt.id, choice: .letGo)
        presenter.tapCTA()
        presenter.tapCTA()
        XCTAssertEqual(router.dismissed, 1)

        let settings = store.effectiveSettings
        let expectedThaw = settings.paydayAfter(max(grinder.thawsAt, now), calendar: .current)
        let waited = try XCTUnwrap(store.want(id: grinder.id))
        XCTAssertEqual(waited.status, .cooling)
        XCTAssertEqual(waited.thawsAt, expectedThaw)
        XCTAssertGreaterThan(waited.thawsAt, now)
        XCTAssertLessThan(waited.thawsAt, settings.paydayAfter(expectedThaw, calendar: .current))

        let letGo = try XCTUnwrap(store.want(id: shirt.id))
        XCTAssertEqual(letGo.status, .skipped)
        XCTAssertNotNil(letGo.decidedOn)
        XCTAssertEqual(store.want(id: keyboard.id)?.status, .bought)
        XCTAssertEqual(store.want(id: quick.id)?.status, .bought)

        let queue = Set(store.reviewQueue.map(\.id))
        XCTAssertFalse(queue.contains(keyboard.id))
        XCTAssertFalse(queue.contains(shirt.id))
        XCTAssertFalse(queue.contains(quick.id))

        // The decisions are on disk, not only in memory.
        let reloaded = WantStore(fileURL: fileURL)
        XCTAssertEqual(reloaded.want(id: grinder.id)?.thawsAt, expectedThaw)
        XCTAssertEqual(reloaded.want(id: shirt.id)?.status, .skipped)
    }
}
