import XCTest
@testable import Thaw

@MainActor
final class PresenterHomeTests: XCTestCase {
    private final class FakeView: HomeViewProtocol {
        var models: [HomeViewModel] = []
        var confirmation: (id: UUID, confirmation: HomeDeleteConfirmation)?
        func render(_ model: HomeViewModel) { models.append(model) }
        func showDeleteConfirmation(id: UUID, confirmation: HomeDeleteConfirmation) { self.confirmation = (id, confirmation) }
    }

    private final class FakeInteractor: HomeInteractorProtocol {
        init() {}
        weak var output: HomeInteractorOutput?
        var cooling: [Want] = []
        var queue: [Want] = []
        var deleted: [UUID] = []
        func delete(_ id: UUID) { deleted.append(id) }
        func snapshot() -> HomeSnapshot {
            HomeSnapshot(cooling: cooling, reviewQueue: queue,
                         payday: PaydaySchedule(nextPayday: .now.addingTimeInterval(86_400 * 3), funMoney: 300),
                         settings: .default)
        }
    }

    private final class FakeRouter: HomeRouterProtocol {
        var calls: [String] = []
        func showAddWant() { calls.append("add") }
        func showPaydayPreview() { calls.append("preview") }
        func showItemDetail(id: UUID) { calls.append("detail") }
        func showEdit(id: UUID) { calls.append("edit") }
    }

    private func make() -> (HomePresenter, FakeView, FakeInteractor, FakeRouter) {
        let view = FakeView(), interactor = FakeInteractor(), router = FakeRouter()
        return (HomePresenter(view: view, interactor: interactor, router: router), view, interactor, router)
    }

    func testEmptyStateDisablesPaydayCard() {
        let (presenter, view, _, _) = make()
        presenter.viewWillAppear()
        let model = view.models.last
        XCTAssertEqual(model?.hasReview, false)
        XCTAssertEqual(model?.emptyText, "Nothing cooling. Add a want to start the wait.")
        XCTAssertEqual(model?.cards.count, 0)
    }

    func testCardsAndSubtitleReflectQueue() {
        let (presenter, view, interactor, _) = make()
        let keyboard = Fixture.want("Keyboard", 189)
        interactor.cooling = [keyboard, Fixture.want("Case", 24)]
        interactor.queue = [keyboard]
        presenter.viewWillAppear()
        let model = view.models.last
        XCTAssertEqual(model?.hasReview, true)
        XCTAssertEqual(model?.paydaySubtitle, "1 want thaws then · S$189 vs S$300 fun money")
        XCTAssertEqual(model?.cards.map(\.isTimer), [false, true])
        XCTAssertNil(model?.emptyText)
    }

    func testPaydayTapIsIgnoredWhenQueueEmpty() {
        let (presenter, _, interactor, router) = make()
        presenter.tapPayday()
        XCTAssertEqual(router.calls, [])
        interactor.queue = [Fixture.want("Keyboard", 189)]
        presenter.tapPayday()
        XCTAssertEqual(router.calls, ["preview"])
    }

    func testDataChangeRerenders() {
        let (presenter, view, _, _) = make()
        presenter.dataDidChange()
        XCTAssertEqual(view.models.count, 1)
    }

    func testAddAndWantTapsRoute() {
        let (presenter, _, _, router) = make()
        presenter.tapAdd()
        presenter.tapWant(id: UUID())
        XCTAssertEqual(router.calls, ["add", "detail"])
    }

    func testEditOpensEditorOnlyForACoolingWant() {
        let (presenter, _, interactor, router) = make()
        let keyboard = Fixture.want("Keyboard", 189)
        interactor.cooling = [keyboard]
        presenter.tapEdit(id: UUID())
        XCTAssertEqual(router.calls, [])
        presenter.tapEdit(id: keyboard.id)
        XCTAssertEqual(router.calls, ["edit"])
    }

    func testDeleteAsksBeforeDeleting() {
        let (presenter, view, interactor, _) = make()
        let keyboard = Fixture.want("Keyboard", 189)
        interactor.cooling = [keyboard]
        presenter.tapDelete(id: keyboard.id)
        XCTAssertEqual(view.confirmation?.id, keyboard.id)
        XCTAssertEqual(view.confirmation?.confirmation.title, "Delete Keyboard?")
        XCTAssertTrue(interactor.deleted.isEmpty)
        presenter.confirmDelete(id: keyboard.id)
        XCTAssertEqual(interactor.deleted, [keyboard.id])
    }

    func testDeleteIgnoresUnknownWants() {
        let (presenter, view, interactor, _) = make()
        presenter.tapDelete(id: UUID())
        presenter.confirmDelete(id: UUID())
        XCTAssertNil(view.confirmation)
        XCTAssertTrue(interactor.deleted.isEmpty)
    }

    func testCardsCarryTimeLeftAndConciseStatus() {
        let (presenter, view, interactor, _) = make()
        var timer = Fixture.want("Case", 24)
        timer.thawsAt = Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now
        var soon = Fixture.want("Keyboard", 189)
        soon.thawsAt = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
        interactor.cooling = [timer, soon, Fixture.want("Today", 100)]
        presenter.viewWillAppear()
        let cards = view.models.last?.cards
        XCTAssertEqual(cards?.map(\.trailingText), ["2 days", "1 day", "Today"])
        XCTAssertTrue(cards?[0].statusText.hasPrefix("2-day timer · ") == true)
        XCTAssertTrue(cards?[1].statusText.hasPrefix("Payday · ") == true)
    }
}
