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
        var wantExists = true
        var settings = PaydaySettings.default
        func waitOnePayday() {}
        func skip() {}
    }

    private final class FakeRouter: ItemDetailRouterProtocol {
        var edited: [UUID] = []
        var opened: [URL] = []
        func openLink(_ url: URL) { opened.append(url) }
        func showDecideNow(want: Want) {}
        func showEdit(wantID: UUID) { edited.append(wantID) }
        var popped = 0
        func pop() { popped += 1 }
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

    func testNoLinkHidesLinkRow() {
        let view = FakeView(), interactor = FakeInteractor()
        let presenter = ItemDetailPresenter(view: view, interactor: interactor, router: FakeRouter())
        presenter.viewDidLoad()
        XCTAssertNil(view.models.last?.linkText)
    }

    func testLinkShowsHostWithoutWWW() {
        let view = FakeView(), interactor = FakeInteractor()
        interactor.want.link = URL(string: "https://www.example.com/products/keyboard?ref=1")
        let presenter = ItemDetailPresenter(view: view, interactor: interactor, router: FakeRouter())
        presenter.viewDidLoad()
        XCTAssertEqual(view.models.last?.linkText, "Open link · example.com")
    }

    func testTapLinkOpensThroughRouter() {
        let view = FakeView(), interactor = FakeInteractor(), router = FakeRouter()
        let url = URL(string: "https://shop.example.com/item")!
        interactor.want.link = url
        let presenter = ItemDetailPresenter(view: view, interactor: interactor, router: router)
        presenter.tapLink()
        XCTAssertEqual(router.opened, [url])
    }

    func testTapLinkWithoutLinkDoesNothing() {
        let view = FakeView(), interactor = FakeInteractor(), router = FakeRouter()
        let presenter = ItemDetailPresenter(view: view, interactor: interactor, router: router)
        presenter.tapLink()
        XCTAssertTrue(router.opened.isEmpty)
    }

    func testDidEditPopsWhenTheWantWasDeleted() {
        let view = FakeView(), interactor = FakeInteractor(), router = FakeRouter()
        let presenter = ItemDetailPresenter(view: view, interactor: interactor, router: router)
        presenter.viewDidLoad()
        interactor.wantExists = false
        presenter.didEdit()
        XCTAssertEqual(router.popped, 1)
        XCTAssertEqual(view.models.count, 1)
    }
}
