import XCTest
@testable import Thaw

@MainActor
final class PresenterSavedTests: XCTestCase {
    private final class FakeView: SavedViewProtocol {
        var model: SavedViewModel?
        var renders = 0
        var deleteConfirmation: (id: UUID, confirmation: SavedDeleteConfirmation)?
        func render(_ model: SavedViewModel) { self.model = model; renders += 1 }
        func showDeleteConfirmation(id: UUID, confirmation: SavedDeleteConfirmation) {
            deleteConfirmation = (id, confirmation)
        }
    }

    private final class FakeInteractor: SavedInteractorProtocol {
        init() {}
        deinit {}
        weak var output: SavedInteractorOutput?
        var wants: [Want] = []
        var funMoney: Decimal = 300
        var deleted: [UUID] = []
        func delete(_ id: UUID) { deleted.append(id) }
    }

    private final class FakeRouter: SavedRouterProtocol {
        var edited: [UUID] = []
        func showEdit(id: UUID) { edited.append(id) }
    }

    private func render(_ wants: [Want]) -> SavedViewModel? {
        let view = FakeView(), interactor = FakeInteractor()
        interactor.wants = wants
        let presenter = SavedPresenter(view: view, interactor: interactor, router: FakeRouter())
        presenter.viewWillAppear()
        return view.model
    }

    private func want(_ name: String, _ price: Decimal, _ status: Want.Status, daysAgo: Int = 0) -> Want {
        let date = Date.now.addingTimeInterval(-86_400 * Double(daysAgo))
        return Want(id: UUID(), name: name, price: price, reason: "r", frozenOn: date,
                    progress: 1, status: status, thawsAt: date)
    }

    func testNothingDecidedShowsEmptyState() {
        let model = render([want("Case", 24, .cooling)])
        XCTAssertEqual(model?.savedText, Formatting.sgd(0))
        XCTAssertNil(model?.progress)
        XCTAssertNotNil(model?.emptyText)
        XCTAssertEqual(model?.history, [])
    }

    func testProgressCardShowsThreeStats() {
        let model = render([want("Shirt", 69, .skipped), want("Grinder", 420, .skipped), want("Keyboard", 189, .bought)])
        XCTAssertEqual(model?.savedText, Formatting.sgd(489))
        XCTAssertNil(model?.emptyText)
        let stats = model?.progress?.stats
        XCTAssertEqual(stats?.count, 3)
        XCTAssertEqual(stats?[1].value, "1.6")
        XCTAssertEqual(stats?[1].caption, "months of fun money")
        XCTAssertEqual(stats?[2].value, "67%")
        XCTAssertEqual(stats?[2].caption, "let go · 2 of 3")
        XCTAssertEqual(stats?[2].spoken, "67 percent let go. You skipped 2 of 3 wants you froze.")
    }

    func testHistoryListsDecidedWantsNewestFirst() {
        let model = render([want("Old", 50, .skipped, daysAgo: 10), want("New", 80, .bought, daysAgo: 1), want("Cooling", 20, .cooling)])
        XCTAssertEqual(model?.history.map(\.name), ["New", "Old"])
        XCTAssertEqual(model?.history.map(\.outcome), ["Bought", "Skipped"])
    }

    func testCubiIsFrozenUntilSomethingIsDecided() {
        let model = render([want("Case", 24, .cooling)])
        XCTAssertEqual(model?.cubi.mood, .frozen)
    }

    func testCubiIsProudDuringAStreak() {
        let model = render([want("Shirt", 69, .skipped)])
        XCTAssertEqual(model?.cubi.mood, .proud)
        XCTAssertEqual(model?.cubi.line, CubiMood.proud.line)
    }

    private func make(_ wants: [Want]) -> (SavedPresenter, FakeView, FakeInteractor) {
        let view = FakeView(), interactor = FakeInteractor()
        interactor.wants = wants
        return (SavedPresenter(view: view, interactor: interactor, router: FakeRouter()), view, interactor)
    }

    func testHistoryRowsCarryWantIDs() {
        let shirt = want("Shirt", 69, .skipped)
        XCTAssertEqual(render([shirt])?.history.map(\.id), [shirt.id])
    }

    func testDataChangeRerendersWithLatestWants() {
        let shirt = want("Shirt", 69, .cooling)
        let (presenter, view, interactor) = make([shirt])
        presenter.viewWillAppear()
        XCTAssertTrue(interactor.output === presenter)
        interactor.wants = [want("Shirt", 69, .skipped)]
        interactor.output?.dataDidChange()
        XCTAssertEqual(view.renders, 2)
        XCTAssertEqual(view.model?.savedText, Formatting.sgd(69))
        XCTAssertEqual(view.model?.history.map(\.name), ["Shirt"])
    }

    func testEditOpensTheEditScreenForDecidedWants() {
        let shirt = want("Shirt", 69, .skipped)
        let view = FakeView(), interactor = FakeInteractor(), router = FakeRouter()
        interactor.wants = [shirt]
        let presenter = SavedPresenter(view: view, interactor: interactor, router: router)
        presenter.tapEdit(id: shirt.id)
        XCTAssertEqual(router.edited, [shirt.id])
    }

    func testEditIgnoresCoolingAndUnknownWants() {
        let cooling = want("Case", 24, .cooling)
        let view = FakeView(), interactor = FakeInteractor(), router = FakeRouter()
        interactor.wants = [cooling]
        let presenter = SavedPresenter(view: view, interactor: interactor, router: router)
        presenter.tapEdit(id: cooling.id)
        presenter.tapEdit(id: UUID())
        XCTAssertTrue(router.edited.isEmpty)
    }

    func testDeleteAsksBeforeDeleting() {
        let shirt = want("Shirt", 69, .skipped)
        let (presenter, view, interactor) = make([shirt])
        presenter.tapDelete(id: shirt.id)
        XCTAssertEqual(view.deleteConfirmation?.id, shirt.id)
        XCTAssertEqual(view.deleteConfirmation?.confirmation.title, "Delete Shirt?")
        XCTAssertEqual(view.deleteConfirmation?.confirmation.deleteTitle, "Delete")
        XCTAssertTrue(interactor.deleted.isEmpty)
        presenter.confirmDelete(id: shirt.id)
        XCTAssertEqual(interactor.deleted, [shirt.id])
    }

    func testConfirmDeleteIgnoresUnknownWant() {
        let (presenter, _, interactor) = make([want("Shirt", 69, .skipped)])
        presenter.confirmDelete(id: UUID())
        XCTAssertTrue(interactor.deleted.isEmpty)
    }

    func testCubiSnoozesWhenStreakIsBroken() {
        let model = render([want("Old", 50, .skipped, daysAgo: 120), want("Keyboard", 189, .bought)])
        XCTAssertEqual(model?.cubi.mood, .snoozing)
    }
}
