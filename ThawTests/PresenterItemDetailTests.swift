import XCTest
@testable import Thaw

@MainActor
final class PresenterItemDetailTests: XCTestCase {
    private final class FakeView: ItemDetailViewProtocol {
        var models: [ItemDetailViewModel] = []
        func render(_ model: ItemDetailViewModel) { models.append(model) }
        func showSkipMoment(line: String, completion: @escaping () -> Void) {}
    }

    private final class FakeInteractor: ItemDetailInteractorProtocol {
        var want = Fixture.want("Keyboard", 189)
        var settings = PaydaySettings.default
        func waitOnePayday() {}
        func skip() {}
    }

    private final class FakeRouter: ItemDetailRouterProtocol {
        var edited: [UUID] = []
        func showDecideNow(want: Want) {}
        func showEdit(wantID: UUID) { edited.append(wantID) }
        func pop() {}
    }

    func testTapEditOpensEditorForThisWant() {
        let view = FakeView(), interactor = FakeInteractor(), router = FakeRouter()
        let presenter = ItemDetailPresenter(view: view, interactor: interactor, router: router)
        presenter.tapEdit()
        XCTAssertEqual(router.edited, [interactor.want.id])
    }

    func testDidEditRerendersFromLatestWant() {
        let view = FakeView(), interactor = FakeInteractor(), router = FakeRouter()
        let presenter = ItemDetailPresenter(view: view, interactor: interactor, router: router)
        presenter.viewDidLoad()
        interactor.want.name = "Keyboard Pro"
        presenter.didEdit()
        XCTAssertEqual(view.models.map(\.name), ["Keyboard", "Keyboard Pro"])
    }
}
