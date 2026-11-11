import Foundation

final class PaydayPresenter: PaydayPresenterProtocol, PaydayInteractorOutput {
    private weak var view: PaydayViewProtocol?
    private let interactor: PaydayInteractorProtocol
    private let router: PaydayRouterProtocol
    private var reminderBusy = false
    private var reminderSetOn: Date?

    // Explicit deinit: the synthesized one on a MainActor class with weak refs corrupts the heap in the test host.
    deinit {}

    init(view: PaydayViewProtocol, interactor: PaydayInteractorProtocol, router: PaydayRouterProtocol) {
        self.view = view
        self.interactor = interactor
        self.router = router
        interactor.output = self
    }

    func viewWillAppear() { refresh() }

    func dataDidChange() { refresh() }

    func tapReview() {
        let wants = readyWants(interactor.snapshot())
        guard !wants.isEmpty else { return }
        router.showReview(wants: wants)
    }

    func tapRemindTonight() {
        let snapshot = interactor.snapshot()
        guard reminderState(now: snapshot.now) == .idle, !readyWants(snapshot).isEmpty else { return }
        reminderBusy = true
        refresh()
        interactor.remindTonight { [weak self] in
            guard let self else { return }
            reminderBusy = false
            reminderSetOn = interactor.snapshot().now
            view?.playSuccessFeedback()
            refresh()
        }
    }

    func tapWant(id: UUID) { router.showItemDetail(id: id) }

    // MARK: - Model

    private func readyWants(_ snapshot: PaydaySnapshot) -> [Want] {
        PaydayReadiness.ready(queue: snapshot.reviewQueue, now: snapshot.now)
    }

    private func reminderState(now: Date) -> PaydayReminderState {
        if reminderBusy { return .busy }
        if let reminderSetOn, Calendar.current.isDate(reminderSetOn, inSameDayAs: now) { return .set }
        return .idle
    }

    private func refresh() {
        let snapshot = interactor.snapshot()
        let now = snapshot.now
        let nextPayday = snapshot.payday.nextPayday
        let funMoney = snapshot.payday.funMoney
        let ready = readyWants(snapshot)
        let readyIDs = Set(ready.map(\.id))
        let thawing = snapshot.cooling.enumerated()
            .filter { !readyIDs.contains($0.element.id) && $0.element.thawsAt <= nextPayday }
            .sorted { ($0.element.thawsAt, $0.offset) < ($1.element.thawsAt, $1.offset) }
            .map(\.element)

        var sections: [PaydaySectionViewModel] = []
        if !ready.isEmpty {
            sections.append(PaydaySectionViewModel(
                title: "Ready", detail: Formatting.sgd(Self.total(ready)),
                rows: ready.map { readyRow($0, settings: snapshot.settings) }))
        }
        if !thawing.isEmpty {
            sections.append(PaydaySectionViewModel(
                title: "Thawing this payday", detail: Formatting.sgd(Self.total(thawing)),
                rows: thawing.map { thawingRow($0, settings: snapshot.settings, now: now) }))
        }

        let isEmpty = snapshot.cooling.isEmpty
        let state = reminderState(now: now)
        let model: PaydayViewModel
        if ready.isEmpty {
            let total = Self.total(thawing)
            let isOver = total > funMoney
            let days = Self.days(from: now, to: nextPayday)
            model = PaydayViewModel(
                title: "Payday", mood: .frozen,
                heroValue: Self.daysText(days),
                heroCaption: "to \(Formatting.paydayDate(nextPayday))",
                heroSpoken: Self.countdownSpoken(days: days, payday: nextPayday, count: thawing.count,
                                                 total: total, funMoney: funMoney),
                showsCubi: !isEmpty,
                budget: isEmpty ? nil : PaydayBudgetViewModel(
                    text: "\(Formatting.sgd(total)) of \(Formatting.sgd(funMoney))",
                    fraction: Self.fraction(total, of: funMoney), isOver: isOver),
                reviewTitle: nil, reminderTitle: "Remind me tonight", reminderState: state,
                sections: sections, emptyLine: isEmpty ? "Nothing on ice." : nil)
        } else {
            let total = Self.total(ready)
            model = PaydayViewModel(
                title: "Payday", mood: .thawed,
                heroValue: "\(ready.count) ready",
                heroCaption: "\(Formatting.sgd(total)) · \(Formatting.sgd(funMoney)) fun money",
                heroSpoken: "\(ready.count) \(ready.count == 1 ? "want" : "wants") ready to decide, "
                    + "\(Formatting.sgd(total)) against your \(Formatting.sgd(funMoney)) fun money.",
                showsCubi: true, budget: nil,
                reviewTitle: "Review",
                reminderTitle: state == .set ? "Reminder set" : "Remind me tonight", reminderState: state,
                sections: sections, emptyLine: nil)
        }
        view?.render(model)
    }

    private func readyRow(_ want: Want, settings: PaydaySettings) -> PaydayRowViewModel {
        let isTimer = want.price < settings.timerThreshold
        return PaydayRowViewModel(id: want.id, row: WantRowModel(
            title: want.name, priceText: Formatting.sgd(want.price),
            leadingSymbol: isTimer ? "timer" : "calendar", tone: isTimer ? .timer : .accent,
            accessibilityLabel: "\(want.name), \(Formatting.sgd(want.price))",
            accessibilityValue: "Ready to decide"))
    }

    private func thawingRow(_ want: Want, settings: PaydaySettings, now: Date) -> PaydayRowViewModel {
        let isTimer = want.price < settings.timerThreshold
        let date = Formatting.paydayDate(want.thawsAt)
        let days = Self.days(from: now, to: want.thawsAt)
        let value = isTimer
            ? "\(settings.timerDays)-day timer, thaws \(date), \(Self.daysText(days).lowercased())"
            : "Thaws on payday, \(date)"
        return PaydayRowViewModel(id: want.id, row: WantRowModel(
            title: want.name, priceText: Formatting.sgd(want.price),
            leadingSymbol: isTimer ? "timer" : "calendar", tone: isTimer ? .timer : .accent,
            trailing: isTimer ? Self.daysText(days) : nil,
            accessibilityLabel: "\(want.name), \(Formatting.sgd(want.price))",
            accessibilityValue: value))
    }

    // MARK: - Copy

    static func daysText(_ days: Int) -> String {
        switch days {
        case ...0: "Today"
        case 1: "1 day"
        default: "\(days) days"
        }
    }

    private static func countdownSpoken(days: Int, payday: Date, count: Int, total: Decimal, funMoney: Decimal) -> String {
        let date = spokenDate(payday)
        let countdown = switch days {
        case ...0: "Payday is today, \(date)."
        case 1: "1 day to payday, \(date)."
        default: "\(days) days to payday, \(date)."
        }
        guard count > 0 else { return countdown + " Nothing thaws then." }
        var budget = "\(count) \(count == 1 ? "want thaws" : "wants thaw") then, "
            + "\(Formatting.sgd(total)) of your \(Formatting.sgd(funMoney)) fun money"
        if total > funMoney { budget += ", \(Formatting.sgd(total - funMoney)) over" }
        return "\(countdown) \(budget)."
    }

    private static func spokenDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_SG")
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: date)
    }

    private static func days(from now: Date, to date: Date) -> Int {
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: date).day ?? 0
    }

    private static func total(_ wants: [Want]) -> Decimal {
        wants.reduce(Decimal(0)) { $0 + $1.price }
    }

    private static func fraction(_ total: Decimal, of budget: Decimal) -> Double {
        guard budget > 0 else { return total > 0 ? 1 : 0 }
        return NSDecimalNumber(decimal: total / budget).doubleValue
    }
}
