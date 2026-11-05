import XCTest
@testable import Thaw

@MainActor
final class PresenterSavedTests: XCTestCase {
    private final class FakeView: SavedViewProtocol {
        var model: SavedViewModel?
        func render(_ model: SavedViewModel) { self.model = model }
    }

    private final class FakeInteractor: SavedInteractorProtocol {
        var wants: [Want] = []
        var funMoney: Decimal = 300
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

    func testCubiSnoozesWhenStreakIsBroken() {
        let model = render([want("Old", 50, .skipped, daysAgo: 120), want("Keyboard", 189, .bought)])
        XCTAssertEqual(model?.cubi.mood, .snoozing)
    }
}
