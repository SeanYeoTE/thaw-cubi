import Foundation

final class AddWantPresenter: AddWantPresenterProtocol {
    private weak var view: AddWantViewProtocol?
    private let interactor: AddWantInteractorProtocol
    private let router: AddWantRouterProtocol
    private var saving = false
    private let now: () -> Date
    private let calendar: Calendar

    // Explicit deinit: the synthesized one on a MainActor class with weak refs corrupts the heap in the test host.
    deinit {}

    init(view: AddWantViewProtocol, interactor: AddWantInteractorProtocol, router: AddWantRouterProtocol,
         now: @escaping () -> Date = { .now }, calendar: Calendar = .current) {
        self.now = now
        self.calendar = calendar
        self.view = view
        self.interactor = interactor
        self.router = router
    }

    private var initial: AddWantInput?
    private var isEditing = false

    func viewDidLoad() {
        if let want = interactor.editing {
            let decided = want.status != .cooling
            let input = AddWantInput(name: want.name, price: Self.priceText(want.price), reason: want.reason,
                                     status: decided ? want.status : nil)
            initial = input
            isEditing = true
            view?.configure(AddWantScreen(title: "Edit want", actionTitle: "Save", discardTitle: "Discard changes?",
                                          discardMessage: "Edits won't be saved.", initial: input,
                                          statusOptions: decided ? Self.statusOptions : [], deleteTitle: "Delete"))
            view?.render(thawLine: thawLine(for: input))
            return
        }
        if let draft = interactor.draft {
            let input = AddWantInput(name: draft.name, price: "", reason: "")
            initial = input
            view?.configure(AddWantScreen(title: "Add to Thaw", actionTitle: "Add to Thaw", discardTitle: "Discard?",
                                          discardMessage: "Nothing will be saved.", initial: input,
                                          caption: draft.link.map { "From \(ShareItemParser.displayHost($0))" }))
            view?.render(thawLine: nil)
            return
        }
        view?.configure(AddWantScreen(title: "Add to Thaw", actionTitle: "Add to Thaw", discardTitle: "Discard?",
                                      discardMessage: "Nothing will be saved.", initial: nil))
        view?.render(thawLine: nil)
    }

    func inputChanged(_ input: AddWantInput) {
        view?.render(thawLine: thawLine(for: input))
        view?.setModalInPresentation(hasInput(input) && !saving)
    }

    func tapCancel(_ input: AddWantInput) { discardOrDismiss(input) }

    func didAttemptDismiss(_ input: AddWantInput) { view?.showDiscardConfirmation() }

    func confirmDiscard() { router.dismiss() }

    func tapSave(_ input: AddWantInput) {
        guard let (name, price) = validated(input) else { return }
        saving = true
        view?.setModalInPresentation(false)
        if isEditing {
            interactor.save(name: name, price: price, reason: input.reason)
            applyStatus(input.status)
            return router.dismiss()
        }
        interactor.add(name: name, price: price, reason: input.reason)
        view?.showSavedMoment(line: CubiMood.frozen.line) { [weak self] in self?.router.dismiss() }
    }

    func tapDelete() {
        guard isEditing else { return }
        let name = interactor.editing?.name ?? "this want"
        view?.showDeleteConfirmation(AddWantDeleteConfirmation(
            title: "Delete \(name)?",
            message: "This can't be undone.",
            deleteTitle: "Delete", cancelTitle: "Cancel"))
    }

    func confirmDelete() {
        guard isEditing else { return }
        interactor.deleteWant()
        finishEditing()
    }

    private func finishEditing() {
        saving = true
        view?.setModalInPresentation(false)
        router.dismiss()
    }

    private func validated(_ input: AddWantInput) -> (String, Decimal)? {
        let name = input.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            view?.showError("Add a name for the item.")
            return nil
        }
        guard let price = Decimal(string: input.price), price > 0 else {
            view?.showError("Enter a price above S$0.")
            return nil
        }
        return (name, price)
    }

    private static let statusOptions = [
        AddWantStatusOption(status: .cooling, title: "Cooling"),
        AddWantStatusOption(status: .bought, title: "Bought"),
        AddWantStatusOption(status: .skipped, title: "Let go"),
    ]

    private func applyStatus(_ status: Want.Status?) {
        guard let status, let current = interactor.editing?.status, status != current else { return }
        if status == .cooling { interactor.moveBackToCooling() } else { interactor.setDecision(status) }
    }

    /// Mirrors `WantStore.makeCoolingWant` and `WantStore.edit`: under the threshold is a timer from now, otherwise payday.
    private func thawLine(for input: AddWantInput) -> String? {
        guard interactor.draft == nil else { return nil }
        let want = interactor.editing
        if let want, want.status != .cooling {
            return input.status == .cooling ? reopenLine(for: want, price: Self.price(in: input) ?? want.price) : nil
        }
        guard let rounded = Self.price(in: input) else { return nil }
        let settings = interactor.settings
        let now = self.now()
        let isTimer = rounded < settings.timerThreshold
        let timerEnd = calendar.date(byAdding: .day, value: settings.timerDays, to: now) ?? now
        let payday = { settings.nextPayday(after: now, calendar: self.calendar) }
        guard let want else {
            return isTimer ? Self.quickThaw(days: settings.timerDays) : "Thaws on payday · \(Self.shortDate(payday()))"
        }
        if (want.price < settings.timerThreshold) != isTimer {
            return isTimer ? "Moves to quick thaw · \(Self.shortDate(timerEnd))"
                : "Moves to payday · \(Self.shortDate(payday()))"
        }
        guard want.thawsAt > now else { return nil }
        if isTimer {
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now),
                                               to: calendar.startOfDay(for: want.thawsAt)).day ?? 1
            return Self.quickThaw(days: max(days, 1))
        }
        return "Thaws on payday · \(Self.shortDate(want.thawsAt))"
    }

    /// `WantStore.reopen` keeps the original `thawsAt`, and `edit` doesn't move it for decided wants, so this
    /// shows that date even when the new price crosses the timer threshold.
    private func reopenLine(for want: Want, price: Decimal) -> String {
        guard want.thawsAt > now() else { return "Back to cooling · ready to review now" }
        let kind = price < interactor.settings.timerThreshold ? "quick thaw" : "thaws on payday"
        return "Back to cooling · \(kind) · \(Self.shortDate(want.thawsAt))"
    }

    /// The typed price rounded to cents, as `WantStore` stores it; nil when empty or not above zero.
    private static func price(in input: AddWantInput) -> Decimal? {
        guard var typed = Decimal(string: input.price.trimmingCharacters(in: .whitespacesAndNewlines)), typed > 0 else { return nil }
        var rounded = Decimal()
        NSDecimalRound(&rounded, &typed, 2, .plain)
        return rounded
    }

    private static func quickThaw(days: Int) -> String {
        "Quick thaw · \(days) \(days == 1 ? "day" : "days")"
    }

    private static func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_SG")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    private func discardOrDismiss(_ input: AddWantInput) {
        if hasInput(input) { view?.showDiscardConfirmation() } else { router.dismiss() }
    }

    private static func priceText(_ price: Decimal) -> String {
        NSDecimalNumber(decimal: price).stringValue
    }

    private func hasInput(_ input: AddWantInput) -> Bool {
        if let initial { return normalized(input) != normalized(initial) }
        return [input.name, input.price, input.reason].contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func normalized(_ input: AddWantInput) -> AddWantInput {
        AddWantInput(name: input.name.trimmingCharacters(in: .whitespacesAndNewlines),
                     price: input.price.trimmingCharacters(in: .whitespacesAndNewlines),
                     reason: input.reason.trimmingCharacters(in: .whitespacesAndNewlines),
                     status: input.status)
    }
}
