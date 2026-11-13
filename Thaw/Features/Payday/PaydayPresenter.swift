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

    /// Quick thaws (price under the timer threshold) are decided whenever their timer ends, not at the
    /// payday review, so they never count against fun money. They get their own section instead.
    static func isQuickThaw(_ want: Want, settings: PaydaySettings) -> Bool {
        FunMoneyPlan.isQuickThaw(want, timerThreshold: settings.timerThreshold)
    }

    private func refresh() {
        let snapshot = interactor.snapshot()
        let now = snapshot.now
        let settings = snapshot.settings
        let nextPayday = snapshot.payday.nextPayday
        let funMoney = snapshot.payday.funMoney
        let ready = readyWants(snapshot)
        let readyIDs = Set(ready.map(\.id))
        let thawing = snapshot.cooling.filter { !readyIDs.contains($0.id) && $0.thawsAt <= nextPayday }

        let readyPlan = FunMoneyPlan.make(wants: ready, funMoney: funMoney, timerThreshold: settings.timerThreshold)
        let thawingPlan = FunMoneyPlan.make(wants: thawing, funMoney: funMoney,
                                            timerThreshold: settings.timerThreshold)

        var sections: [PaydaySectionViewModel] = []
        let readyRows = { (want: Want) in self.readyRow(want, settings: settings) }
        let thawingRows = { (want: Want) in self.thawingRow(want, settings: settings, now: now) }
        if ready.isEmpty {
            sections += Self.budgetSections(thawingPlan, underTitle: "Thawing this payday", row: thawingRows)
        } else {
            sections += Self.budgetSections(readyPlan, underTitle: "Ready", row: readyRows)
            sections += Self.section("Quick thaws", readyPlan.quickThaws, row: readyRows)
            sections += Self.section("Thawing this payday", thawingPlan.payday.map(\.want), row: thawingRows)
        }
        sections += Self.section("Quick thaws", thawingPlan.quickThaws, row: thawingRows)

        let isEmpty = snapshot.cooling.isEmpty
        let state = reminderState(now: now)
        let model: PaydayViewModel
        if ready.isEmpty {
            let days = Self.days(from: now, to: nextPayday)
            model = PaydayViewModel(
                title: "Payday", mood: .frozen,
                heroValue: Self.daysText(days),
                heroCaption: "to \(Formatting.paydayDate(nextPayday))",
                heroSpoken: Self.countdownSpoken(days: days, payday: nextPayday, hasWants: !thawing.isEmpty),
                showsCubi: !isEmpty,
                budget: isEmpty ? nil : Self.budget(thawingPlan, verb: "thawing"),
                reviewTitle: nil, reminderTitle: "Remind me tonight", reminderState: state,
                sections: sections, emptyLine: isEmpty ? "Nothing on ice." : nil)
        } else {
            model = PaydayViewModel(
                title: "Payday", mood: .thawed,
                heroValue: "\(ready.count) ready",
                heroCaption: "\(Formatting.sgd(Self.total(ready))) to decide",
                heroSpoken: "\(ready.count) \(ready.count == 1 ? "want" : "wants") ready to decide, "
                    + "\(Formatting.sgd(Self.total(ready))).",
                showsCubi: true,
                budget: readyPlan.payday.isEmpty ? nil : Self.budget(readyPlan, verb: "ready"),
                reviewTitle: "Review",
                reminderTitle: state == .set ? "Reminder set" : "Remind me tonight", reminderState: state,
                sections: sections, emptyLine: nil)
        }
        view?.render(model)
    }

    // MARK: - Budget

    /// Spoken-for against fun money: every payday want in the plan. Exactly on budget still fits ("S$0 left").
    static func budget(_ plan: FunMoneyPlan, verb: String) -> PaydayBudgetViewModel {
        let total = plan.paydayTotal
        let funMoney = plan.funMoney
        let headline = plan.isOver
            ? "\(Formatting.sgd(plan.overBy)) over"
            : "\(Formatting.sgd(plan.left)) left"
        let amounts = "\(Formatting.sgd(total)) \(verb) against \(Formatting.sgd(funMoney)) fun money"
        return PaydayBudgetViewModel(
            headline: headline,
            caption: "\(Formatting.sgd(total)) \(verb) · \(Formatting.sgd(funMoney)) fun money",
            spoken: "\(headline). \(amounts).",
            fillFraction: fraction(total, of: funMoney),
            markerFraction: plan.isOver ? fraction(funMoney, of: total) : 1,
            isOver: plan.isOver)
    }

    /// One section when every payday want fits; otherwise "Fits" and "Over budget" by the plan's best fit
    /// in thaw order, so a later, cheaper want can still fit after an earlier one overflowed (D5).
    static func budgetSections(_ plan: FunMoneyPlan, underTitle: String,
                               row: (Want) -> PaydayRowViewModel) -> [PaydaySectionViewModel] {
        guard plan.isOver else { return section(underTitle, plan.fits, row: row) }
        return section("Fits", plan.fits, row: row) + section("Over budget", plan.over, row: row)
    }

    private static func section(_ title: String, _ wants: [Want],
                                row: (Want) -> PaydayRowViewModel) -> [PaydaySectionViewModel] {
        guard !wants.isEmpty else { return [] }
        return [PaydaySectionViewModel(title: title, detail: Formatting.sgd(total(wants)), rows: wants.map(row))]
    }

    private func readyRow(_ want: Want, settings: PaydaySettings) -> PaydayRowViewModel {
        let isTimer = Self.isQuickThaw(want, settings: settings)
        return PaydayRowViewModel(id: want.id, row: WantRowModel(
            title: want.name, priceText: Formatting.sgd(want.price),
            leadingSymbol: isTimer ? "timer" : "calendar", tone: isTimer ? .timer : .accent,
            accessibilityLabel: "\(want.name), \(Formatting.sgd(want.price))",
            accessibilityValue: "Ready to decide"))
    }

    private func thawingRow(_ want: Want, settings: PaydaySettings, now: Date) -> PaydayRowViewModel {
        let isTimer = Self.isQuickThaw(want, settings: settings)
        let date = Formatting.paydayDate(want.thawsAt)
        let days = Self.days(from: now, to: want.thawsAt)
        let value = isTimer
            ? "\(settings.timerDays)-day timer, thaws \(date), \(Self.daysText(days).lowercased())"
            : "Thaws on payday, \(date), \(Self.daysText(days).lowercased())"
        return PaydayRowViewModel(id: want.id, row: WantRowModel(
            title: want.name, priceText: Formatting.sgd(want.price),
            leadingSymbol: isTimer ? "timer" : "calendar", tone: isTimer ? .timer : .accent,
            trailing: Self.daysText(days),
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

    private static func countdownSpoken(days: Int, payday: Date, hasWants: Bool) -> String {
        let date = spokenDate(payday)
        let countdown = switch days {
        case ...0: "Payday is today, \(date)."
        case 1: "1 day to payday, \(date)."
        default: "\(days) days to payday, \(date)."
        }
        return hasWants ? countdown : countdown + " Nothing thaws then."
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
