import XCTest
@testable import Thaw

@MainActor
final class PresenterAddWantTests: XCTestCase {
    private final class FakeView: AddWantViewProtocol {
        var note: String?
        var modal: [Bool] = []
        var errors: [String] = []
        var discardShown = 0
        var momentLine: String?
        var momentCompletion: (() -> Void)?
        func render(note: String) { self.note = note }
        func setModalInPresentation(_ isModal: Bool) { modal.append(isModal) }
        func showError(_ message: String) { errors.append(message) }
        func showDiscardConfirmation() { discardShown += 1 }
        func showSavedMoment(line: String, completion: @escaping () -> Void) {
            momentLine = line
            momentCompletion = completion
        }
    }

    private final class FakeInteractor: AddWantInteractorProtocol {
        var settings = PaydaySettings.default
        var added: [(String, Decimal, String)] = []
        func add(name: String, price: Decimal, reason: String) { added.append((name, price, reason)) }
    }

    private final class FakeRouter: AddWantRouterProtocol {
        var dismissed = 0
        func dismiss() { dismissed += 1 }
    }

    private func make() -> (AddWantPresenter, FakeView, FakeInteractor, FakeRouter) {
        let view = FakeView(), interactor = FakeInteractor(), router = FakeRouter()
        return (AddWantPresenter(view: view, interactor: interactor, router: router), view, interactor, router)
    }

    private let empty = AddWantInput(name: "", price: "", reason: "")

    func testNoteUsesSettings() {
        let (presenter, view, _, _) = make()
        presenter.viewDidLoad()
        XCTAssertEqual(view.note, "Thaw will read this back to you when it thaws. Items under S$30 use a 2-day timer; the rest thaw on payday.")
    }

    func testValidationErrors() {
        let (presenter, view, interactor, _) = make()
        presenter.tapSave(empty)
        presenter.tapSave(AddWantInput(name: "Lamp", price: "0", reason: ""))
        presenter.tapSave(AddWantInput(name: "Lamp", price: "abc", reason: ""))
        XCTAssertEqual(view.errors, ["Add a name for the item.", "Enter a price above S$0.", "Enter a price above S$0."])
        XCTAssertTrue(interactor.added.isEmpty)
    }

    func testSaveAddsShowsMomentThenDismissesOnce() {
        let (presenter, view, interactor, router) = make()
        presenter.tapSave(AddWantInput(name: " Lamp ", price: "29.5", reason: "Dim"))
        XCTAssertEqual(interactor.added.first?.0, "Lamp")
        XCTAssertEqual(interactor.added.first?.1, Decimal(string: "29.5"))
        XCTAssertEqual(view.momentLine, CubiMood.frozen.line)
        XCTAssertEqual(view.modal.last, false)
        XCTAssertEqual(router.dismissed, 0)
        view.momentCompletion?()
        XCTAssertEqual(router.dismissed, 1)
    }

    func testDirtyGuard() {
        let (presenter, view, _, router) = make()
        presenter.inputChanged(AddWantInput(name: "x", price: "", reason: ""))
        XCTAssertEqual(view.modal.last, true)
        presenter.inputChanged(empty)
        XCTAssertEqual(view.modal.last, false)

        presenter.tapCancel(empty)
        XCTAssertEqual(router.dismissed, 1)
        presenter.tapCancel(AddWantInput(name: "x", price: "", reason: ""))
        XCTAssertEqual(view.discardShown, 1)
        XCTAssertEqual(router.dismissed, 1)
        presenter.didAttemptDismiss(empty)
        XCTAssertEqual(view.discardShown, 2)
        presenter.confirmDiscard()
        XCTAssertEqual(router.dismissed, 2)
    }
}
