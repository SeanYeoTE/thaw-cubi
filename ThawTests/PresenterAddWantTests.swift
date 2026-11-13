import UIKit
import XCTest
@testable import Thaw

@MainActor
final class PresenterAddWantTests: XCTestCase {
    private final class FakeView: AddWantViewProtocol {
        var thawLine: String?
        var modal: [Bool] = []
        var errors: [String] = []
        var discardShown = 0
        var momentLine: String?
        var momentCompletion: (() -> Void)?
        var screen: AddWantScreen?
        func configure(_ screen: AddWantScreen) { self.screen = screen }
        func render(thawLine: String?) { self.thawLine = thawLine }
        func setModalInPresentation(_ isModal: Bool) { modal.append(isModal) }
        func showError(_ message: String) { errors.append(message) }
        func showDiscardConfirmation() { discardShown += 1 }
        var deleteConfirmation: AddWantDeleteConfirmation?
        func showDeleteConfirmation(_ confirmation: AddWantDeleteConfirmation) { deleteConfirmation = confirmation }
        func showSavedMoment(line: String, completion: @escaping () -> Void) {
            momentLine = line
            momentCompletion = completion
        }
    }

    private final class FakeInteractor: AddWantInteractorProtocol {
        var settings = PaydaySettings.default
        var editing: Want?
        var draft: AddWantDraft?
        var added: [(String, Decimal, String)] = []
        var saved: [(String, Decimal, String)] = []
        /// Every store change, in the order the presenter made them.
        var ops: [String] = []
        func moveBackToCooling() { ops.append("reopen") }
        func setDecision(_ status: Want.Status) { ops.append("set-\(status)") }
        func deleteWant() { ops.append("delete") }
        func add(name: String, price: Decimal, reason: String) { added.append((name, price, reason)) }
        func save(name: String, price: Decimal, reason: String) {
            saved.append((name, price, reason))
            ops.append("save")
        }
    }

    private final class FakeRouter: AddWantRouterProtocol {
        var dismissed = 0
        func dismiss() { dismissed += 1 }
    }

    private func make() -> (AddWantPresenter, FakeView, FakeInteractor, FakeRouter) {
        let view = FakeView(), interactor = FakeInteractor(), router = FakeRouter()
        return (AddWantPresenter(view: view, interactor: interactor, router: router, now: { self.now }, calendar: calendar),
                view, interactor, router)
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Singapore")!
        return calendar
    }

    /// 12 Nov 2026, 10:00 in Singapore; default settings put the next payday on 25 Nov.
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 10))!
    }

    private let empty = AddWantInput(name: "", price: "", reason: "")

    private func line(for price: String, in presenter: AddWantPresenter, _ view: FakeView) -> String? {
        presenter.inputChanged(AddWantInput(name: "Lamp", price: price, reason: ""))
        return view.thawLine
    }

    func testThawLineForPaydayAndQuickThaw() {
        let (presenter, view, _, _) = make()
        presenter.viewDidLoad()
        XCTAssertNil(view.thawLine)
        XCTAssertEqual(line(for: "45", in: presenter, view), "Thaws on payday · 25 Nov")
        XCTAssertEqual(line(for: "30", in: presenter, view), "Thaws on payday · 25 Nov")
        XCTAssertEqual(line(for: "29.99", in: presenter, view), "Quick thaw · 2 days")
    }

    func testThawLineHiddenForEmptyOrInvalidPrices() {
        let (presenter, view, _, _) = make()
        presenter.viewDidLoad()
        _ = line(for: "45", in: presenter, view)
        for price in ["", " ", "abc", "0", "-5"] {
            XCTAssertNil(line(for: price, in: presenter, view), price)
        }
    }

    func testThawLineIsHiddenForShareDrafts() {
        let (presenter, view, _, _) = makeDraft()
        XCTAssertNil(view.thawLine)
        XCTAssertNil(line(for: "45", in: presenter, view))
    }

    func testEditingACoolingWantShowsItsDateThenTheNewOneWhenCrossingTheThreshold() {
        let (presenter, view, interactor, _) = make()
        var want = Fixture.want("Keyboard", 189, reason: "")
        want.thawsAt = calendar.date(from: DateComponents(year: 2026, month: 11, day: 25, hour: 9))!
        interactor.editing = want
        presenter.viewDidLoad()
        XCTAssertEqual(view.thawLine, "Thaws on payday · 25 Nov")
        XCTAssertEqual(line(for: "250", in: presenter, view), "Thaws on payday · 25 Nov")
        XCTAssertEqual(line(for: "20", in: presenter, view), "Moves to quick thaw · 14 Nov")
        XCTAssertNil(line(for: "", in: presenter, view))
    }

    func testEditingATimerWantCrossingUpMovesToPayday() {
        let (presenter, view, interactor, _) = make()
        var want = Fixture.want("Pen", 10, reason: "")
        want.thawsAt = calendar.date(from: DateComponents(year: 2026, month: 11, day: 14, hour: 10))!
        interactor.editing = want
        presenter.viewDidLoad()
        XCTAssertEqual(view.thawLine, "Quick thaw · 2 days")
        XCTAssertEqual(line(for: "80", in: presenter, view), "Moves to payday · 25 Nov")
    }

    func testDecidedWantsHaveNoThawLine() {
        XCTAssertNil(makeEditing(status: .bought).1.thawLine)
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

    private func makeEditing() -> (AddWantPresenter, FakeView, FakeInteractor, FakeRouter) {
        let made = make()
        made.2.editing = Fixture.want("Keyboard", 189, reason: "Double-types")
        made.0.viewDidLoad()
        return made
    }

    func testEditModePrefillsAndRetitles() {
        let (_, view, _, _) = makeEditing()
        XCTAssertEqual(view.screen?.title, "Edit want")
        XCTAssertEqual(view.screen?.actionTitle, "Save")
        XCTAssertEqual(view.screen?.initial, AddWantInput(name: "Keyboard", price: "189", reason: "Double-types"))
    }

    func testEditWithoutChangesDismissesWithoutConfirmation() {
        let (presenter, view, _, router) = makeEditing()
        let same = AddWantInput(name: "Keyboard", price: "189", reason: "Double-types")
        presenter.inputChanged(same)
        XCTAssertEqual(view.modal.last, false)
        presenter.tapCancel(same)
        XCTAssertEqual(router.dismissed, 1)
        XCTAssertEqual(view.discardShown, 0)
    }

    func testEditWithChangesAsksBeforeDiscarding() {
        let (presenter, view, _, router) = makeEditing()
        let changed = AddWantInput(name: "Keyboard", price: "199", reason: "Double-types")
        presenter.inputChanged(changed)
        XCTAssertEqual(view.modal.last, true)
        presenter.tapCancel(changed)
        XCTAssertEqual(view.discardShown, 1)
        XCTAssertEqual(router.dismissed, 0)
    }

    func testEditSaveUpdatesAndDismissesWithoutMoment() {
        let (presenter, view, interactor, router) = makeEditing()
        presenter.tapSave(AddWantInput(name: " Keyboard 2 ", price: "199", reason: "Double-types"))
        XCTAssertEqual(interactor.saved.count, 1)
        XCTAssertEqual(interactor.saved.first?.0, "Keyboard 2")
        XCTAssertEqual(interactor.saved.first?.1, 199)
        XCTAssertTrue(interactor.added.isEmpty)
        XCTAssertNil(view.momentLine)
        XCTAssertEqual(router.dismissed, 1)
    }

    func testEditStillValidatesFields() {
        let (presenter, view, interactor, _) = makeEditing()
        presenter.tapSave(AddWantInput(name: "", price: "199", reason: ""))
        presenter.tapSave(AddWantInput(name: "Keyboard", price: "0", reason: ""))
        XCTAssertEqual(view.errors.count, 2)
        XCTAssertTrue(interactor.saved.isEmpty)
    }

    // MARK: Share sheet draft

    private func makeDraft(link: URL? = URL(string: "https://www.example.com/lamp")) -> (AddWantPresenter, FakeView, FakeInteractor, FakeRouter) {
        let made = make()
        made.2.draft = AddWantDraft(name: "Brass desk lamp", link: link)
        made.0.viewDidLoad()
        return made
    }

    func testDraftPrefillsNameAndShowsHostCaption() {
        let (_, view, _, _) = makeDraft()
        XCTAssertEqual(view.screen?.title, "Add to Thaw")
        XCTAssertEqual(view.screen?.actionTitle, "Add to Thaw")
        XCTAssertEqual(view.screen?.initial, AddWantInput(name: "Brass desk lamp", price: "", reason: ""))
        XCTAssertEqual(view.screen?.caption, "From example.com")
    }

    func testDraftWithoutLinkHasNoCaption() {
        let (_, view, _, _) = makeDraft(link: nil)
        XCTAssertNil(view.screen?.caption)
        XCTAssertEqual(view.screen?.initial?.name, "Brass desk lamp")
    }

    func testPlainAddAndEditHaveNoCaption() {
        let (presenter, view, _, _) = make()
        presenter.viewDidLoad()
        XCTAssertNil(view.screen?.caption)
        XCTAssertNil(makeEditing().1.screen?.caption)
    }

    func testDraftUntouchedCancelsWithoutConfirmation() {
        let (presenter, view, _, router) = makeDraft()
        let prefilled = AddWantInput(name: "Brass desk lamp", price: "", reason: "")
        presenter.inputChanged(prefilled)
        XCTAssertEqual(view.modal.last, false)
        presenter.tapCancel(AddWantInput(name: " Brass desk lamp ", price: " ", reason: ""))
        XCTAssertEqual(view.discardShown, 0)
        XCTAssertEqual(router.dismissed, 1)
    }

    func testDraftAsksBeforeDiscardingAfterAChange() {
        let (presenter, view, _, router) = makeDraft()
        let typed = AddWantInput(name: "Brass desk lamp", price: "45", reason: "")
        presenter.inputChanged(typed)
        XCTAssertEqual(view.modal.last, true)
        presenter.tapCancel(typed)
        XCTAssertEqual(view.discardShown, 1)
        XCTAssertEqual(router.dismissed, 0)
        presenter.confirmDiscard()
        XCTAssertEqual(router.dismissed, 1)

        let cleared = AddWantInput(name: "", price: "", reason: "")
        presenter.inputChanged(cleared)
        XCTAssertEqual(view.modal.last, true, "Clearing the prefilled name is a change")
    }

    func testDraftSaveAddsTypedFieldsShowsMomentThenFinishes() {
        let (presenter, view, interactor, router) = makeDraft()
        presenter.tapSave(AddWantInput(name: " Brass lamp ", price: "45.90", reason: "Reading corner"))
        XCTAssertEqual(interactor.added.count, 1)
        XCTAssertEqual(interactor.added.first?.0, "Brass lamp")
        XCTAssertEqual(interactor.added.first?.1, Decimal(string: "45.90"))
        XCTAssertEqual(interactor.added.first?.2, "Reading corner")
        XCTAssertTrue(interactor.saved.isEmpty)
        XCTAssertEqual(view.momentLine, CubiMood.frozen.line)
        XCTAssertEqual(router.dismissed, 0)
        view.momentCompletion?()
        XCTAssertEqual(router.dismissed, 1)
    }

    func testDraftStillNeedsAPrice() {
        let (presenter, view, interactor, _) = makeDraft()
        presenter.tapSave(AddWantInput(name: "Brass desk lamp", price: "", reason: ""))
        XCTAssertEqual(view.errors, ["Enter a price above S$0."])
        XCTAssertTrue(interactor.added.isEmpty)
    }

    private func makeEditing(status: Want.Status) -> (AddWantPresenter, FakeView, FakeInteractor, FakeRouter) {
        let made = make()
        var want = Fixture.want("Keyboard", 189, reason: "Double-types")
        want.status = status
        made.2.editing = want
        made.0.viewDidLoad()
        return made
    }

    func testStatusRowOnlyForDecidedWantsAndMatchesTheCurrentStatus() {
        let cooling = makeEditing(status: .cooling).1.screen
        XCTAssertEqual(cooling?.statusOptions, [])
        XCTAssertNil(cooling?.initial?.status)
        XCTAssertEqual(cooling?.deleteTitle, "Delete")
        for status in [Want.Status.skipped, .bought] {
            let screen = makeEditing(status: status).1.screen
            XCTAssertEqual(screen?.statusOptions.map(\.title), ["Cooling", "Bought", "Let go"])
            XCTAssertEqual(screen?.statusOptions.map(\.status), [.cooling, .bought, .skipped])
            XCTAssertEqual(screen?.initial?.status, status)
        }
        let add = make()
        add.0.viewDidLoad()
        XCTAssertEqual(add.1.screen?.statusOptions, [])
        XCTAssertNil(add.1.screen?.deleteTitle)
    }

    func testSaveAppliesTheChosenStatus() {
        func run(from: Want.Status, to: Want.Status) -> [String] {
            let (presenter, _, interactor, router) = makeEditing(status: from)
            presenter.tapSave(AddWantInput(name: "Keyboard", price: "189", reason: "Double-types", status: to))
            XCTAssertEqual(router.dismissed, 1)
            XCTAssertEqual(interactor.saved.count, 1)
            return interactor.ops
        }
        XCTAssertEqual(run(from: .skipped, to: .cooling), ["save", "reopen"])
        XCTAssertEqual(run(from: .skipped, to: .bought), ["save", "set-bought"])
        XCTAssertEqual(run(from: .bought, to: .skipped), ["save", "set-skipped"])
        XCTAssertEqual(run(from: .bought, to: .bought), ["save"])
    }

    func testSaveKeepsEditsTypedWithAStatusChange() {
        let (presenter, _, interactor, _) = makeEditing(status: .bought)
        presenter.tapSave(AddWantInput(name: "Keyboard Pro", price: "199", reason: "Double-types", status: .skipped))
        XCTAssertEqual(interactor.saved.first?.0, "Keyboard Pro")
        XCTAssertEqual(interactor.ops, ["save", "set-skipped"])
    }

    func testInvalidEditsWithAStatusChangeChangeNothing() {
        let (presenter, view, interactor, router) = makeEditing(status: .skipped)
        presenter.tapSave(AddWantInput(name: "", price: "189", reason: "", status: .cooling))
        XCTAssertEqual(view.errors.count, 1)
        XCTAssertTrue(interactor.ops.isEmpty)
        XCTAssertTrue(interactor.saved.isEmpty)
        XCTAssertEqual(router.dismissed, 0)
    }

    func testChangingOnlyTheStatusIsDirtyAndAsksBeforeDiscarding() {
        let (presenter, view, _, router) = makeEditing(status: .skipped)
        let unchanged = AddWantInput(name: "Keyboard", price: "189", reason: "Double-types", status: .skipped)
        presenter.inputChanged(unchanged)
        XCTAssertEqual(view.modal.last, false)
        var changed = unchanged
        changed.status = .bought
        presenter.inputChanged(changed)
        XCTAssertEqual(view.modal.last, true)
        presenter.tapCancel(changed)
        XCTAssertEqual(view.discardShown, 1)
        XCTAssertEqual(router.dismissed, 0)
    }

    // MARK: Reopening a decided want

    private func makeDecided(_ status: Want.Status, price: Decimal = 189, thawsOn day: Int)
        -> (AddWantPresenter, FakeView, FakeInteractor, FakeRouter) {
        let made = make()
        var want = Fixture.want("Keyboard", price, reason: "Double-types")
        want.status = status
        want.thawsAt = calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: 9))!
        made.2.editing = want
        made.0.viewDidLoad()
        return made
    }

    private func reopenLine(_ presenter: AddWantPresenter, _ view: FakeView, price: String = "189",
                            status: Want.Status = .cooling) -> String? {
        presenter.inputChanged(AddWantInput(name: "Keyboard", price: price, reason: "Double-types", status: status))
        return view.thawLine
    }

    func testReopeningAPastDueWantSaysItIsReadyNow() {
        let (presenter, view, _, _) = makeDecided(.skipped, thawsOn: 1)
        XCTAssertNil(view.thawLine)
        XCTAssertEqual(reopenLine(presenter, view), "Back to cooling · ready to review now")
    }

    func testReopeningAWantStillCoolingShowsItsOriginalDate() {
        let (presenter, view, _, _) = makeDecided(.bought, thawsOn: 25)
        XCTAssertEqual(reopenLine(presenter, view), "Back to cooling · thaws on payday · 25 Nov")
        let quick = makeDecided(.skipped, price: 12, thawsOn: 14)
        XCTAssertEqual(reopenLine(quick.0, quick.1, price: "12"), "Back to cooling · quick thaw · 14 Nov")
    }

    func testReopeningAcrossTheThresholdKeepsTheStoredDate() {
        let (presenter, view, _, _) = makeDecided(.skipped, thawsOn: 25)
        XCTAssertEqual(reopenLine(presenter, view, price: "20"), "Back to cooling · quick thaw · 25 Nov")
        XCTAssertEqual(reopenLine(presenter, view, price: ""), "Back to cooling · thaws on payday · 25 Nov")
    }

    func testDecidedWantLeftDecidedHasNoThawLine() {
        for status in [Want.Status.bought, .skipped] {
            let (presenter, view, _, _) = makeDecided(status, thawsOn: 25)
            XCTAssertNil(reopenLine(presenter, view, status: .bought), "\(status)")
            XCTAssertNil(reopenLine(presenter, view, status: .skipped), "\(status)")
            XCTAssertNotNil(reopenLine(presenter, view, status: .cooling), "\(status)")
            XCTAssertNil(reopenLine(presenter, view, status: status), "switching back hides it again")
        }
    }

    func testReopenSavesFieldsBeforeReopening() {
        let (presenter, _, interactor, router) = makeDecided(.skipped, thawsOn: 1)
        presenter.tapSave(AddWantInput(name: "Keyboard Pro", price: "20", reason: "Double-types", status: .cooling))
        XCTAssertEqual(interactor.ops, ["save", "reopen"])
        XCTAssertEqual(interactor.saved.first?.1, 20)
        XCTAssertEqual(router.dismissed, 1)
    }

    // MARK: Edit sheet layout

    func testDeleteKeepsItsGapWithAndWithoutAnError() {
        for status in [Want.Status.cooling, .bought] {
            let controller = AddWantViewController()
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 1400))
            window.rootViewController = controller
            window.isHidden = false
            var want = Fixture.want("Keyboard", 189, reason: "")
            want.status = status
            controller.configure(AddWantScreen(
                title: "Edit want", actionTitle: "Save", discardTitle: "", discardMessage: "",
                initial: AddWantInput(name: "Keyboard", price: "189", reason: "", status: status == .cooling ? nil : status),
                statusOptions: status == .cooling ? [] : [AddWantStatusOption(status: .cooling, title: "Cooling")],
                deleteTitle: "Delete"))
            XCTAssertEqual(deleteGap(in: controller), AddWantViewController.deleteSpacing, accuracy: 0.5, "\(status)")
            controller.showError("Add a name for the item.")
            XCTAssertEqual(deleteGap(in: controller), AddWantViewController.deleteSpacing, accuracy: 0.5,
                           "\(status) with error")
            window.isHidden = true
        }
    }

    /// Distance from the bottom of the last visible view above Delete to Delete itself.
    private func deleteGap(in controller: AddWantViewController) -> CGFloat {
        controller.view.layoutIfNeeded()
        guard let stack = Self.find(UIStackView.self, in: controller.view, where: { stack in
            stack.arrangedSubviews.contains { $0.accessibilityIdentifier == "addwant.delete" }
        }) else { return -1 }
        let views = stack.arrangedSubviews
        guard let index = views.firstIndex(where: { $0.accessibilityIdentifier == "addwant.delete" }),
              // Skips hidden views and the plain spacer that makes up the gap.
              let above = views[..<index].last(where: { !$0.isHidden && type(of: $0) != UIView.self })
        else { return -1 }
        return views[index].frame.minY - above.frame.maxY
    }

    private static func find<T: UIView>(_ type: T.Type, in view: UIView, where match: (T) -> Bool) -> T? {
        if let view = view as? T, match(view) { return view }
        for sub in view.subviews { if let found = find(type, in: sub, where: match) { return found } }
        return nil
    }

    func testDeleteAsksThenDeletesAndDismisses() {
        let (presenter, view, interactor, router) = makeEditing(status: .cooling)
        presenter.tapDelete()
        XCTAssertEqual(view.deleteConfirmation?.title, "Delete Keyboard?")
        XCTAssertTrue(interactor.ops.isEmpty)
        XCTAssertEqual(router.dismissed, 0)
        presenter.confirmDelete()
        XCTAssertEqual(interactor.ops, ["delete"])
        XCTAssertEqual(router.dismissed, 1)
    }

    func testDeleteIsIgnoredOutsideEditMode() {
        let (presenter, view, interactor, router) = make()
        presenter.viewDidLoad()
        presenter.tapDelete()
        presenter.confirmDelete()
        XCTAssertNil(view.deleteConfirmation)
        XCTAssertTrue(interactor.ops.isEmpty)
        XCTAssertEqual(router.dismissed, 0)
    }
}
