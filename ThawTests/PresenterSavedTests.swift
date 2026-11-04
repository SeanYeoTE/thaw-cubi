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
        Want(id: UUID(), name: name, price: price, reason: "r",
             frozenOn: .now.addingTimeInterval(-86_400 * Double(daysAgo)),
             progress: 1, status: status, thawsAt: .now)
    }

    func testNothingDecidedShowsEmptyHistory() {
        let model = render([want("Case", 24, .cooling)])
        XCTAssertEqual(model?.savedText, Formatting.sgd(0))
        XCTAssertEqual(model?.skippedText, "0 of 0")
        XCTAssertEqual(model?.history, [])
    }

    func testSavedIsSumOfSkippedPrices() {
        let model = render([want("Shirt", 69, .skipped), want("Grinder", 420, .skipped), want("Keyboard", 189, .bought)])
        XCTAssertEqual(model?.savedText, Formatting.sgd(489))
        XCTAssertEqual(model?.skippedText, "2 of 3")
    }

    func testHistoryListsDecidedWantsNewestFirst() {
        let model = render([want("Old", 50, .skipped, daysAgo: 10), want("New", 80, .bought, daysAgo: 1), want("Cooling", 20, .cooling)])
        XCTAssertEqual(model?.history.map(\.name), ["New", "Old"])
        XCTAssertEqual(model?.history.map(\.outcome), ["Bought", "Skipped"])
    }
}
