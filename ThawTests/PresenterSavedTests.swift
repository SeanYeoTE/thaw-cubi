import XCTest
@testable import Thaw

@MainActor
final class PresenterSavedTests: XCTestCase {
    private final class FakeView: SavedViewProtocol {
        var model: SavedViewModel?
        var renders = 0
        var sheet: (id: UUID, sheet: SavedDecisionSheet)?
        var deleteConfirmation: (id: UUID, confirmation: SavedDeleteConfirmation)?
        func render(_ model: SavedViewModel) { self.model = model; renders += 1 }
        func showDecisionOptions(id: UUID, sheet: SavedDecisionSheet) { self.sheet = (id, sheet) }
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
        var reopened: [UUID] = []
        var decisions: [(UUID, Want.Status)] = []
        var deleted: [UUID] = []
        func reopen(_ id: UUID) { reopened.append(id) }
        func setDecision(_ id: UUID, to status: Want.Status) { decisions.append((id, status)) }
        func delete(_ id: UUID) { deleted.append(id) }
    }

    private final class FakeRouter: SavedRouterProtocol {}

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
        XCTAssertEqual(stats?[1].value, "1.6 months of fun money")
        XCTAssertEqual(stats?[2].value, "67% let go")
        XCTAssertEqual(stats?[2].caption, "You skipped 2 of 3 wants you froze.")
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
        XCTAssertEqual(model?.cubi.line, "S$69 stays with you.")
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

    func testEditOnSkippedOffersCoolingAndBought() {
        let shirt = want("Shirt", 69, .skipped)
        let (presenter, view, _) = make([shirt])
        presenter.tapEditDecision(id: shirt.id)
        XCTAssertEqual(view.sheet?.id, shirt.id)
        XCTAssertEqual(view.sheet?.sheet.title, "Shirt")
        XCTAssertEqual(view.sheet?.sheet.choices, [
            SavedDecisionChoice(option: .moveBackToCooling, title: "Move back to cooling"),
            SavedDecisionChoice(option: .markBought, title: "Mark as bought"),
        ])
        XCTAssertEqual(view.sheet?.sheet.cancelTitle, "Cancel")
    }

    func testEditOnBoughtOffersCoolingAndSkipped() {
        let keyboard = want("Keyboard", 189, .bought)
        let (presenter, view, _) = make([keyboard])
        presenter.tapEditDecision(id: keyboard.id)
        XCTAssertEqual(view.sheet?.sheet.choices.map(\.title), ["Move back to cooling", "Mark as skipped"])
    }

    func testEditIgnoresCoolingAndUnknownWants() {
        let cooling = want("Case", 24, .cooling)
        let (presenter, view, _) = make([cooling])
        presenter.tapEditDecision(id: cooling.id)
        presenter.tapEditDecision(id: UUID())
        XCTAssertNil(view.sheet)
    }

    func testMoveBackToCoolingReopens() {
        let shirt = want("Shirt", 69, .skipped)
        let (presenter, _, interactor) = make([shirt])
        presenter.chooseDecisionOption(id: shirt.id, option: .moveBackToCooling)
        XCTAssertEqual(interactor.reopened, [shirt.id])
        XCTAssertTrue(interactor.decisions.isEmpty)
    }

    func testMarkAsBoughtAndSkippedSetDecision() {
        let shirt = want("Shirt", 69, .skipped), keyboard = want("Keyboard", 189, .bought)
        let (presenter, _, interactor) = make([shirt, keyboard])
        presenter.chooseDecisionOption(id: shirt.id, option: .markBought)
        presenter.chooseDecisionOption(id: keyboard.id, option: .markSkipped)
        XCTAssertEqual(interactor.decisions.map(\.0), [shirt.id, keyboard.id])
        XCTAssertEqual(interactor.decisions.map(\.1), [.bought, .skipped])
        XCTAssertTrue(interactor.reopened.isEmpty)
    }

    func testChoosingTheCurrentDecisionDoesNothing() {
        let shirt = want("Shirt", 69, .skipped)
        let (presenter, _, interactor) = make([shirt])
        presenter.chooseDecisionOption(id: shirt.id, option: .markSkipped)
        XCTAssertTrue(interactor.decisions.isEmpty)
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
