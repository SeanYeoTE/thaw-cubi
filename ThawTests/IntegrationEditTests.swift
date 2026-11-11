import XCTest
@testable import Thaw

/// Real file-backed store with the real AddWant and Home interactors; only views, router and scheduler are fakes.
@MainActor
final class IntegrationEditTests: XCTestCase {
    private final class FakeAddView: AddWantViewProtocol {
        var screen: AddWantScreen?
        func configure(_ screen: AddWantScreen) { self.screen = screen }
        func render(note: String) {}
        func setModalInPresentation(_ isModal: Bool) {}
        func showError(_ message: String) {}
        func showDiscardConfirmation() {}
        func showDeleteConfirmation(_ confirmation: AddWantDeleteConfirmation) {}
        func showSavedMoment(line: String, completion: @escaping () -> Void) {}
    }

    private final class FakeAddRouter: AddWantRouterProtocol {
        var dismissed = 0
        func dismiss() { dismissed += 1 }
    }

    private final class FakeHomeView: HomeViewProtocol {
        var models: [HomeViewModel] = []
        func render(_ model: HomeViewModel) { models.append(model) }
        func showDeleteConfirmation(id: UUID, confirmation: HomeDeleteConfirmation) {}
    }

    private final class FakeHomeRouter: HomeRouterProtocol {
        func showAddWant() {}
        func showItemDetail(id: UUID) {}
        func showEdit(id: UUID) {}
    }

    private struct SilentScheduler: NotificationScheduling {
        func requestAuthorizationIfNeeded() async -> Bool { false }
        func schedulePaydayReview(at: Date, thawingCount: Int, total: Decimal) async {}
        func scheduleTimerThaw(wantID: UUID, name: String, at: Date) async {}
        func scheduleReminder(at: Date, thawingCount: Int, total: Decimal) async {}
        func cancelAll() async {}
    }

    private func makeFileURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("IntegrationEdit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory.appendingPathComponent("state.json")
    }

    private func editPresenter(store: WantStore, id: UUID, router: FakeAddRouter, view: FakeAddView) -> AddWantPresenter {
        let reminders = Reminders(store: store) { _ in SilentScheduler() }
        let interactor = AddWantInteractor(store: store, reminders: reminders, editingID: id)
        let presenter = AddWantPresenter(view: view, interactor: interactor, router: router)
        presenter.viewDidLoad()
        return presenter
    }

    func testMovingADecidedWantBackReachesTheStoreAndHome() throws {
        let fileURL = try makeFileURL()
        let store = WantStore(fileURL: fileURL)
        store.save(settings: .default)
        store.add(name: "Grinder", price: 420, reason: "Better coffee")
        let grinder = try XCTUnwrap(store.wants.first)
        store.update(grinder.id, status: .skipped)

        let homeView = FakeHomeView()
        let reminders = Reminders(store: store) { _ in SilentScheduler() }
        let home = HomePresenter(view: homeView, interactor: HomeInteractor(store: store, reminders: reminders),
                                 router: FakeHomeRouter())
        home.viewWillAppear()
        XCTAssertEqual(homeView.models.last?.cards.count, 0)

        let router = FakeAddRouter(), view = FakeAddView()
        let presenter = editPresenter(store: store, id: grinder.id, router: router, view: view)
        XCTAssertEqual(view.screen?.actions.map(\.kind), [.moveBackToCooling, .markBought, .delete])
        presenter.tapAction(.moveBackToCooling,
                            input: AddWantInput(name: "Grinder", price: "420", reason: "Better coffee"))

        XCTAssertEqual(router.dismissed, 1)
        XCTAssertEqual(store.want(id: grinder.id)?.status, .cooling)
        XCTAssertEqual(store.want(id: grinder.id)?.thawsAt, grinder.thawsAt)
        XCTAssertEqual(homeView.models.last?.cards.map(\.name), ["Grinder"])
        XCTAssertEqual(WantStore(fileURL: fileURL).want(id: grinder.id)?.status, .cooling)
    }

    func testDeletingFromTheEditScreenRemovesItEverywhere() throws {
        let fileURL = try makeFileURL()
        let store = WantStore(fileURL: fileURL)
        store.save(settings: .default)
        store.add(name: "Lamp", price: 45, reason: "Dim light")
        let lamp = try XCTUnwrap(store.wants.first)

        let homeView = FakeHomeView()
        let reminders = Reminders(store: store) { _ in SilentScheduler() }
        let home = HomePresenter(view: homeView, interactor: HomeInteractor(store: store, reminders: reminders),
                                 router: FakeHomeRouter())
        home.viewWillAppear()
        XCTAssertEqual(homeView.models.last?.cards.count, 1)

        let router = FakeAddRouter()
        let presenter = editPresenter(store: store, id: lamp.id, router: router, view: FakeAddView())
        presenter.tapAction(.delete, input: AddWantInput(name: "Lamp", price: "45", reason: "Dim light"))
        XCTAssertNotNil(store.want(id: lamp.id), "Asking first must not delete")
        presenter.confirmDelete()

        XCTAssertNil(store.want(id: lamp.id))
        XCTAssertEqual(router.dismissed, 1)
        XCTAssertEqual(homeView.models.last?.cards.count, 0)
        XCTAssertNil(WantStore(fileURL: fileURL).want(id: lamp.id))
    }

    func testDeletingFromTheCoolingListReachesTheStore() throws {
        let fileURL = try makeFileURL()
        let store = WantStore(fileURL: fileURL)
        store.save(settings: .default)
        store.add(name: "Lamp", price: 45, reason: "Dim light")
        let lamp = try XCTUnwrap(store.wants.first)

        let homeView = FakeHomeView()
        let reminders = Reminders(store: store) { _ in SilentScheduler() }
        let home = HomePresenter(view: homeView, interactor: HomeInteractor(store: store, reminders: reminders),
                                 router: FakeHomeRouter())
        home.viewWillAppear()
        home.confirmDelete(id: lamp.id)
        XCTAssertEqual(homeView.models.last?.cards.count, 0)
        XCTAssertNil(WantStore(fileURL: fileURL).want(id: lamp.id))
    }
}
