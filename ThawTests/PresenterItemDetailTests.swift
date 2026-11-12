import XCTest
@testable import Thaw

@MainActor
final class PresenterItemDetailTests: XCTestCase {
    private final class FakeView: ItemDetailViewProtocol {
        var models: [ItemDetailViewModel] = []
        func render(_ model: ItemDetailViewModel) { models.append(model) }
        var moments: [String] = []
        var confirmations: [(title: String, confirm: String, cancel: String)] = []
        var pendingConfirm: (() -> Void)?
        func showSkipMoment(line: String, completion: @escaping () -> Void) {
            moments.append(line)
            completion()
        }
        func showLetGoConfirmation(title: String, confirmTitle: String, cancelTitle: String, onConfirm: @escaping () -> Void) {
            confirmations.append((title, confirmTitle, cancelTitle))
            pendingConfirm = onConfirm
        }
    }

    private final class FakeInteractor: ItemDetailInteractorProtocol {
        var want = Fixture.want("Keyboard", 189)
        var wantExists = true
        var settings = PaydaySettings.default
        var skipped = 0
        func skip() { skipped += 1 }
    }

    private final class FakeRouter: ItemDetailRouterProtocol {
        var edited: [UUID] = []
        var opened: [URL] = []
        func openLink(_ url: URL) { opened.append(url) }
        var decided: [UUID] = []
        func showDecideNow(want: Want) { decided.append(want.id) }
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

    private func model(_ want: Want, settings: PaydaySettings = .default) -> ItemDetailViewModel {
        let view = FakeView(), interactor = FakeInteractor()
        interactor.want = want
        interactor.settings = settings
        ItemDetailPresenter(view: view, interactor: interactor, router: FakeRouter()).viewDidLoad()
        return view.models[0]
    }

    private func day(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: .now))!
    }

    func testPaydayCaptionAndTone() {
        var want = Fixture.want("Keyboard", 189)
        want.thawsAt = day(5)
        var settings = PaydaySettings.default
        settings.timerThreshold = 50
        let m = model(want, settings: settings)
        XCTAssertTrue(m.captionText.hasPrefix("Thaws on payday · "))
        XCTAssertFalse(m.isTimer)
    }

    func testQuickThawCaptionAndTone() {
        var want = Fixture.want("Mug", 20)
        want.thawsAt = day(2)
        var settings = PaydaySettings.default
        settings.timerThreshold = 50
        let m = model(want, settings: settings)
        XCTAssertTrue(m.captionText.hasPrefix("Quick thaw · "))
        XCTAssertTrue(m.isTimer)
    }

    func testDaysText() {
        var want = Fixture.want("Keyboard", 189)
        want.thawsAt = day(0)
        XCTAssertEqual(model(want).daysText, "Today")
        want.thawsAt = day(1)
        XCTAssertEqual(model(want).daysText, "1 day")
        want.thawsAt = day(14)
        XCTAssertEqual(model(want).daysText, "14 days")
    }

    func testHeaderAndLetGoCopy() {
        let m = model(Fixture.want("Keyboard", 189))
        XCTAssertEqual(m.priceText, "S$189")
        XCTAssertTrue(m.frozenText.hasPrefix("Frozen "))
        XCTAssertEqual(m.letGoTitle, "Let go · save S$189")
    }

    func testEmptyReasonFallback() {
        XCTAssertEqual(model(Fixture.want("Keyboard", 189, reason: "")).quote, "\u{201C}No reason written.\u{201D}")
    }

    func testLetGoAsksFirst() {
        let view = FakeView(), interactor = FakeInteractor(), router = FakeRouter()
        let presenter = ItemDetailPresenter(view: view, interactor: interactor, router: router)
        presenter.tapLetGo()
        XCTAssertEqual(view.confirmations.first?.title, "Let go of Keyboard?")
        XCTAssertEqual(view.confirmations.first?.confirm, "Let go")
        XCTAssertEqual(view.confirmations.first?.cancel, "Cancel")
        XCTAssertEqual(interactor.skipped, 0)
        XCTAssertEqual(router.popped, 0)
    }

    func testConfirmLetGoSkipsAndPops() {
        let view = FakeView(), interactor = FakeInteractor(), router = FakeRouter()
        let presenter = ItemDetailPresenter(view: view, interactor: interactor, router: router)
        presenter.tapLetGo()
        view.pendingConfirm?()
        XCTAssertEqual(interactor.skipped, 1)
        XCTAssertEqual(view.moments.count, 1)
        XCTAssertEqual(router.popped, 1)
    }

    func testTapDecideRoutes() {
        let view = FakeView(), interactor = FakeInteractor(), router = FakeRouter()
        let presenter = ItemDetailPresenter(view: view, interactor: interactor, router: router)
        presenter.tapDecide()
        XCTAssertEqual(router.decided, [interactor.want.id])
    }
}
