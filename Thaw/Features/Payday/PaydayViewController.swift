import UIKit

/// Payday tab: countdown or ready count, how much of fun money is spoken for, Review, and read-only rows split by what fits.
final class PaydayViewController: ScrollStackViewController, PaydayViewProtocol {
    var presenter: PaydayPresenterProtocol?

    private let titleLabel = UILabel()
    private let hero = UIView()
    private let cubi = CubiView(mood: .frozen, size: 96)
    private let valueLabel = UILabel()
    private let captionLabel = UILabel()
    private let budgetStack = UIStackView()
    private let meter = PaydayMeterView()
    private let budgetValueLabel = UILabel()
    private let budgetLabel = UILabel()
    private let topRow = UIView()
    private let reviewButton = PillButton(title: "Review", style: .primary)
    private let remindButton = PillButton(title: "Remind me tonight", style: .quiet)
    private let content = UIStackView()
    private var foregroundToken: NSObjectProtocol?

    init() {
        super.init(nibName: nil, bundle: nil)
        title = "Payday"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func buildContent() {
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.title = ""
        stack.spacing = 16

        titleLabel.text = "Payday"
        titleLabel.font = ThawFont.display(36)
        titleLabel.textColor = Theme.ink
        titleLabel.numberOfLines = 0
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.accessibilityTraits = .header

        reviewButton.accessibilityIdentifier = "payday.review"
        reviewButton.addAction(UIAction { [weak self] _ in self?.presenter?.tapReview() }, for: .touchUpInside)
        remindButton.accessibilityIdentifier = "payday.remind"
        remindButton.addAction(UIAction { [weak self] _ in self?.presenter?.tapRemindTonight() }, for: .touchUpInside)

        content.axis = .vertical
        content.spacing = 24

        [titleLabel, makeHero(), reviewButton, remindButton, content].forEach(stack.addArrangedSubview)
        stack.setCustomSpacing(8, after: reviewButton)
        stack.setCustomSpacing(16, after: remindButton)

        // Timers thaw by date, so coming back to the app can change what's ready.
        foregroundToken = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.presenter?.viewWillAppear() }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        presenter?.viewWillAppear()
    }

    private func makeHero() -> UIView {
        hero.backgroundColor = Theme.paydayCard
        hero.layer.cornerRadius = Theme.Radius.pill
        topRow.isAccessibilityElement = true
        topRow.accessibilityIdentifier = "payday.hero"
        budgetStack.isAccessibilityElement = true
        budgetStack.accessibilityIdentifier = "payday.budget"

        cubi.isAccessibilityElement = false
        cubi.setContentHuggingPriority(.required, for: .horizontal)
        cubi.setContentCompressionResistancePriority(.required, for: .horizontal)

        valueLabel.font = ThawFont.display(40)
        valueLabel.textColor = .white
        captionLabel.font = ThawFont.body(15)
        captionLabel.textColor = Theme.paydayLabel
        budgetValueLabel.font = ThawFont.display(28)
        budgetValueLabel.textColor = .white
        budgetLabel.font = ThawFont.body(14, weight: .medium)
        budgetLabel.textColor = Theme.paydayLabel
        for label in [valueLabel, captionLabel, budgetValueLabel, budgetLabel] {
            label.numberOfLines = 0
            label.adjustsFontForContentSizeCategory = true
        }

        let text = UIStackView(arrangedSubviews: [valueLabel, captionLabel])
        text.axis = .vertical
        text.spacing = 2
        let top = AdaptiveStackView(arrangedSubviews: [cubi, text])
        top.spacing = 16

        budgetStack.axis = .vertical
        budgetStack.spacing = 6
        [budgetValueLabel, meter, budgetLabel].forEach(budgetStack.addArrangedSubview)
        budgetStack.setCustomSpacing(10, after: budgetValueLabel)
        budgetStack.setCustomSpacing(8, after: meter)
        budgetStack.isUserInteractionEnabled = false

        top.isUserInteractionEnabled = false
        top.translatesAutoresizingMaskIntoConstraints = false
        topRow.addSubview(top)
        NSLayoutConstraint.activate([
            top.leadingAnchor.constraint(equalTo: topRow.leadingAnchor),
            top.trailingAnchor.constraint(equalTo: topRow.trailingAnchor),
            top.topAnchor.constraint(equalTo: topRow.topAnchor),
            top.bottomAnchor.constraint(equalTo: topRow.bottomAnchor),
        ])

        let column = UIStackView(arrangedSubviews: [topRow, budgetStack])
        column.axis = .vertical
        column.spacing = 16
        column.translatesAutoresizingMaskIntoConstraints = false
        hero.addSubview(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: hero.leadingAnchor, constant: 18),
            column.trailingAnchor.constraint(equalTo: hero.trailingAnchor, constant: -18),
            column.topAnchor.constraint(equalTo: hero.topAnchor, constant: 18),
            column.bottomAnchor.constraint(equalTo: hero.bottomAnchor, constant: -18),
        ])
        return hero
    }

    // MARK: - PaydayViewProtocol

    func render(_ model: PaydayViewModel) {
        titleLabel.text = model.title
        if cubi.mood != model.mood { cubi.setMood(model.mood, animated: view.window != nil) }
        cubi.isHidden = !model.showsCubi
        valueLabel.text = model.heroValue
        captionLabel.text = model.heroCaption
        topRow.accessibilityLabel = model.heroSpoken

        budgetStack.isHidden = model.budget == nil
        if let budget = model.budget {
            budgetValueLabel.text = budget.headline
            budgetValueLabel.textColor = budget.isOver ? Theme.paydaySubtext : .white
            budgetLabel.text = budget.caption
            budgetStack.accessibilityLabel = budget.spoken
            meter.update(fill: budget.fillFraction, marker: budget.markerFraction, isOver: budget.isOver)
        }

        reviewButton.isHidden = model.reviewTitle == nil
        reviewButton.configuration?.title = model.reviewTitle
        remindButton.isHidden = model.reviewTitle == nil
        remindButton.configuration?.title = model.reminderTitle
        remindButton.isEnabled = model.reminderState == .idle

        content.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for section in model.sections {
            content.addArrangedSubview(makeSection(section))
        }
        if let line = model.emptyLine {
            content.addArrangedSubview(EmptyStateView(mood: .frozen, line: line, actionTitle: nil))
        }
    }

    func playSuccessFeedback() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - Rows

    private func makeSection(_ section: PaydaySectionViewModel) -> UIView {
        let column = UIStackView(arrangedSubviews: [SectionHeaderView(title: section.title, detail: section.detail)])
        column.axis = .vertical
        column.spacing = WantListStyle.rowGap
        column.setCustomSpacing(10, after: column.arrangedSubviews[0])
        for row in section.rows {
            let control = PaydayRowControl(model: row.row)
            control.accessibilityIdentifier = "payday.row"
            let id = row.id
            control.addAction(UIAction { [weak self] _ in self?.presenter?.tapWant(id: id) }, for: .touchUpInside)
            column.addArrangedSubview(control)
        }
        return column
    }
}

/// Read-only want row that opens Item detail; no swipe actions here, editing stays on Cooling.
private final class PaydayRowControl: UIControl {
    init(model: WantRowModel) {
        super.init(frame: .zero)
        let row = WantRowView(model: model)
        row.isUserInteractionEnabled = false
        row.isAccessibilityElement = false
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = model.accessibilityLabel
        accessibilityValue = model.accessibilityValue
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.6 : 1 }
    }
}

/// Budget bar on the dark card: fill is spoken-for against fun money, the white tick marks 100% of fun money
/// so "over" reads without colour.
private final class PaydayMeterView: UIView {
    private let fill = UIView()
    private let marker = UIView()
    private var fillFraction: CGFloat = 0
    private var markerFraction: CGFloat = 1

    init() {
        super.init(frame: .zero)
        backgroundColor = Theme.meterTrack
        layer.cornerRadius = 5
        fill.layer.cornerRadius = 5
        marker.backgroundColor = .white
        addSubview(fill)
        addSubview(marker)
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var intrinsicContentSize: CGSize { CGSize(width: UIView.noIntrinsicMetric, height: 10) }

    func update(fill value: Double, marker position: Double, isOver: Bool) {
        fillFraction = Self.clamp(value)
        markerFraction = Self.clamp(position)
        fill.backgroundColor = isOver ? Theme.warm : Theme.cubeStroke
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        fill.frame = CGRect(x: 0, y: 0, width: bounds.width * fillFraction, height: bounds.height)
        let x = min(max(bounds.width * markerFraction - 1, 0), bounds.width - 2)
        marker.frame = CGRect(x: x, y: 0, width: 2, height: bounds.height)
    }

    private static func clamp(_ value: Double) -> CGFloat {
        value.isFinite ? CGFloat(max(0, min(1, value))) : 0
    }
}
