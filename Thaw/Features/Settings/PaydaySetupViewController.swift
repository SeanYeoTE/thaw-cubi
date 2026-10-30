import UIKit

/// Payday setup: full-screen onboarding when `onSaved` is set, the Settings tab otherwise.
final class PaydaySetupViewController: ScrollStackViewController {
    private enum Kind: CaseIterable { case sameDate, lastWorkingDay, twiceMonthly, fixedWait }

    private let store: WantStore
    private let reminders: Reminders
    private let onSaved: (() -> Void)?

    private var kind: Kind
    private var day: Int
    private var firstDay: Int
    private var waitDays: Int
    private var reviewMinutes: Int
    private var funMoney: Int
    private var timerThreshold: Int
    private var timerDays: Int

    private let choiceStack = UIStackView()
    private let detailHost = UIStackView()
    private let saveButton = PillButton(title: "Save", style: .primary)
    private var resetTitleWork: DispatchWorkItem?

    init(store: WantStore, reminders: Reminders, onSaved: (() -> Void)? = nil) {
        self.store = store
        self.reminders = reminders
        self.onSaved = onSaved
        let current = store.effectiveSettings
        var kind = Kind.sameDate
        var day = 25, firstDay = 15, waitDays = 7
        switch current.rule {
        case .sameDate(let value): kind = .sameDate; day = value
        case .lastWorkingDay: kind = .lastWorkingDay
        case .twiceMonthly(let first, _): kind = .twiceMonthly; firstDay = first
        case .fixedWait(let days): kind = .fixedWait; waitDays = days
        }
        self.kind = kind
        self.day = day
        self.firstDay = firstDay
        self.waitDays = waitDays
        reviewMinutes = current.reviewHour * 60 + current.reviewMinute
        funMoney = Int(truncating: NSDecimalNumber(decimal: current.funMoney))
        timerThreshold = Int(truncating: NSDecimalNumber(decimal: current.timerThreshold))
        timerDays = current.timerDays
        super.init(nibName: nil, bundle: nil)
        title = "Settings"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private var rule: PaydayRule {
        switch kind {
        case .sameDate: .sameDate(day: day)
        case .lastWorkingDay: .lastWorkingDay
        case .twiceMonthly: .twiceMonthly(first: firstDay, second: 31)
        case .fixedWait: .fixedWait(days: waitDays)
        }
    }

    private var currentSettings: PaydaySettings {
        PaydaySettings(rule: rule, reviewHour: reviewMinutes / 60, reviewMinute: reviewMinutes % 60,
                       funMoney: Decimal(funMoney), timerThreshold: Decimal(timerThreshold), timerDays: timerDays)
    }

    override func buildContent() {
        navigationItem.largeTitleDisplayMode = .never
        stack.spacing = 16

        let heading = makeLabel("When's payday?", font: ThawFont.display(34))
        heading.accessibilityTraits = .header
        let subtitle = makeLabel("Wants thaw then, when you can actually afford them.",
                                 font: ThawFont.body(15), color: Theme.inkSecondary)
        let intro = UIStackView(arrangedSubviews: [heading, subtitle])
        intro.axis = .vertical
        intro.spacing = 6
        stack.addArrangedSubview(intro)

        let legend = makeLabel("I get paid", font: ThawFont.body(13, weight: .bold), color: Theme.inkSecondary)
        stack.addArrangedSubview(legend)
        stack.setCustomSpacing(8, after: legend)
        choiceStack.axis = .vertical
        choiceStack.spacing = 8
        stack.addArrangedSubview(choiceStack)
        renderChoices()

        stack.addArrangedSubview(makeSettingsCard())

        let footer = makeLabel("Entered by you, kept on this phone. Thaw never reads your bank.",
                               font: ThawFont.body(13), color: Theme.inkSecondary)
        footer.textAlignment = .center
        stack.addArrangedSubview(footer)

        saveButton.addAction(UIAction { [weak self] _ in self?.save() }, for: .touchUpInside)
        stack.addArrangedSubview(saveButton)
        updateSaveTitle()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(onSaved != nil, animated: false)
    }

    // MARK: Choices

    private func choiceCopy(_ kind: Kind) -> (title: String, hint: String) {
        switch kind {
        case .sameDate:
            return ("Same date every month", "On the \(Self.ordinal(day))")
        case .lastWorkingDay:
            return ("Last working day", "Moves around weekends")
        case .twiceMonthly:
            return ("Twice a month", firstDay == 15 ? "e.g. the 15th and the last day"
                                                    : "The \(Self.ordinal(firstDay)) and the last day")
        case .fixedWait:
            return ("No fixed payday", "Use a fixed wait instead (\(waitDays) days)")
        }
    }

    private func renderChoices() {
        choiceStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for option in Kind.allCases {
            let copy = choiceCopy(option)
            let choice = ChoiceRowView(title: copy.title, hint: copy.hint, selected: option == kind)
            choice.addAction(UIAction { [weak self] _ in
                guard let self, self.kind != option else { return }
                self.kind = option
                self.renderChoices()
                self.renderDetail()
                self.updateSaveTitle()
            }, for: .touchUpInside)
            choiceStack.addArrangedSubview(choice)
        }
    }

    // MARK: Settings card

    private func makeSettingsCard() -> UIView {
        let card = CardView()
        let rows = UIStackView()
        rows.axis = .vertical
        rows.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(rows)
        NSLayoutConstraint.activate([
            rows.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            rows.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            rows.topAnchor.constraint(equalTo: card.topAnchor, constant: 4),
            rows.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -4),
        ])

        detailHost.axis = .vertical
        rows.addArrangedSubview(detailHost)
        renderDetail()

        let review = StepperSettingRow(title: "Payday review at", range: 0...1410, step: 30,
                                       value: Double(reviewMinutes), format: Self.timeText)
        review.onChange = { [weak self, weak review] in
            guard let review else { return }
            self?.reviewMinutes = Int(review.value)
            self?.updateSaveTitle()
        }
        let fun = StepperSettingRow(title: "Fun money each payday", subtitle: "Your limit for thawed wants",
                                    range: 0...5000, step: 50, value: Double(funMoney)) { Formatting.sgd(Decimal($0)) }
        fun.onChange = { [weak self, weak fun] in
            guard let fun else { return }
            self?.funMoney = Int(fun.value)
        }
        let threshold = StepperSettingRow(title: "Use a timer for buys under",
                                          subtitle: "Cheap things don't wait for payday",
                                          range: 0...500, step: 5, value: Double(timerThreshold)) { Formatting.sgd(Decimal($0)) }
        threshold.onChange = { [weak self, weak threshold] in
            guard let threshold else { return }
            self?.timerThreshold = Int(threshold.value)
        }
        let length = StepperSettingRow(title: "Timer length", range: 1...14, step: 1,
                                       value: Double(timerDays)) { "\(Int($0)) \(Int($0) == 1 ? "day" : "days")" }
        length.onChange = { [weak self, weak length] in
            guard let length else { return }
            self?.timerDays = Int(length.value)
        }

        let all = [review, fun, threshold, length]
        for (index, row) in all.enumerated() {
            rows.addArrangedSubview(row)
            if index < all.count - 1 { rows.addArrangedSubview(Self.separator()) }
        }
        return card
    }

    private func renderDetail() {
        detailHost.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let row: StepperSettingRow
        switch kind {
        case .lastWorkingDay:
            return
        case .sameDate:
            row = StepperSettingRow(title: "Payday date", subtitle: "Day of the month", range: 1...31, step: 1,
                                    value: Double(day)) { Self.ordinal(Int($0)) }
        case .twiceMonthly:
            row = StepperSettingRow(title: "First payday", subtitle: "The second is the last day", range: 1...28,
                                    step: 1, value: Double(firstDay)) { Self.ordinal(Int($0)) }
        case .fixedWait:
            row = StepperSettingRow(title: "Wait length", subtitle: "Days before a want thaws", range: 1...60,
                                    step: 1, value: Double(waitDays)) { "\(Int($0)) days" }
        }
        row.onChange = { [weak self, weak row] in
            guard let row else { return }
            self?.dayChanged(Int(row.value))
        }
        detailHost.addArrangedSubview(row)
        detailHost.addArrangedSubview(Self.separator())
    }

    private func dayChanged(_ value: Int) {
        switch kind {
        case .sameDate: day = value
        case .twiceMonthly: firstDay = value
        case .fixedWait: waitDays = value
        case .lastWorkingDay: break
        }
        renderChoices()
        updateSaveTitle()
    }

    // MARK: Save

    private var nextPaydayText: String {
        Formatting.paydayDate(currentSettings.nextPayday(after: .now, calendar: .current))
    }

    private func updateSaveTitle() {
        saveButton.configuration?.title = "Save · next payday \(nextPaydayText)"
    }

    private func save() {
        store.save(settings: currentSettings)
        reminders.refresh(requestingPermission: true)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if let onSaved {
            onSaved()
            return
        }
        saveButton.configuration?.title = "Saved"
        resetTitleWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.updateSaveTitle() }
        resetTitleWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    // MARK: Helpers

    private static func separator() -> UIView {
        let line = UIView()
        line.backgroundColor = UIColor(hex: 0xEDF2F5)
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return line
    }

    private static func ordinal(_ value: Int) -> String {
        let suffix: String
        switch value % 100 {
        case 11...13: suffix = "th"
        default:
            switch value % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(value)\(suffix)"
    }

    private static func timeText(_ minutes: Double) -> String {
        let total = Int(minutes)
        let hour = total / 60, minute = total % 60
        let display = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%d:%02d %@", display, minute, hour < 12 ? "am" : "pm")
    }
}
