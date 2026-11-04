import UIKit

/// Small rounded status tag.
final class TagLabel: UIView {
    enum Style { case fillsFirst, extended, neutral }

    private let label = UILabel()

    init(text: String, style: Style) {
        super.init(frame: .zero)
        layer.cornerRadius = 11
        label.text = text
        label.font = ThawFont.body(12, weight: .bold)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
        ])
        switch style {
        case .fillsFirst: backgroundColor = Theme.frost; label.textColor = Theme.frostText
        case .extended: backgroundColor = Theme.glow; label.textColor = Theme.extendedText
        case .neutral: backgroundColor = Theme.track; label.textColor = Theme.neutralTagText
        }
        isAccessibilityElement = false
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}

/// 8pt goal progress bar; progress is clamped to 0...1.
final class GoalProgressBar: UIView {
    private let fill = UIView()
    private var fillWidth: NSLayoutConstraint?

    init() {
        super.init(frame: .zero)
        backgroundColor = Theme.track
        layer.cornerRadius = 4
        clipsToBounds = true
        fill.backgroundColor = Theme.accent
        fill.layer.cornerRadius = 4
        fill.translatesAutoresizingMaskIntoConstraints = false
        addSubview(fill)
        NSLayoutConstraint.activate([
            fill.leadingAnchor.constraint(equalTo: leadingAnchor),
            fill.topAnchor.constraint(equalTo: topAnchor),
            fill.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalToConstant: 8),
        ])
        setProgress(0)
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func setProgress(_ progress: Double) {
        let value = progress.isFinite ? CGFloat(max(0, min(1, progress))) : 0
        fillWidth?.isActive = false
        let width = fill.widthAnchor.constraint(equalTo: widthAnchor, multiplier: max(value, 0.0001))
        width.isActive = true
        fillWidth = width
    }
}

struct GoalCardModel {
    var name: String
    var savedText: String
    var targetText: String
    var progress: Double
    var deadlineText: String?
    var fillsFirst: Bool
    var extended: Bool
    var accessibilityLabel: String
}

private func axisForCurrentSize(_ traits: UITraitCollection) -> NSLayoutConstraint.Axis {
    traits.preferredContentSizeCategory >= .accessibilityExtraLarge ? .vertical : .horizontal
}

/// Row that is horizontal normally and stacks vertically at AX3 and above.
private final class AdaptiveRow: UIStackView {
    init(_ views: [UIView], alignment: UIStackView.Alignment = .center) {
        super.init(frame: .zero)
        views.forEach(addArrangedSubview)
        spacing = 12
        rowAlignment = alignment
        refreshAxis()
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private var rowAlignment: UIStackView.Alignment = .center

    func refreshAxis() {
        let vertical = axisForCurrentSize(traitCollection) == .vertical
        axis = vertical ? .vertical : .horizontal
        alignment = vertical ? .leading : rowAlignment
        spacing = vertical ? 6 : 12
        distribution = .fill
    }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        refreshAxis()
    }
}

/// Goal card: name, saved of target, progress, deadline, tags.
final class GoalCardView: UIView {
    private let card = CardView()
    private let nameLabel = UILabel()
    private let moneyLabel = UILabel()
    private let percentLabel = UILabel()
    private let bar = GoalProgressBar()
    private let deadlineLabel = UILabel()
    private let headerSlot = UIStackView()
    private let footerSlot = UIStackView()
    private var headerRow: AdaptiveRow!
    private var moneyRow: AdaptiveRow!
    private var footerRow: AdaptiveRow!

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func setUp() {
        nameLabel.font = ThawFont.body(17, weight: .bold)
        nameLabel.textColor = Theme.ink
        nameLabel.numberOfLines = 0
        moneyLabel.numberOfLines = 0
        percentLabel.font = ThawFont.body(14)
        percentLabel.textColor = Theme.inkSecondary
        percentLabel.setContentHuggingPriority(.required, for: .horizontal)
        percentLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        deadlineLabel.font = ThawFont.body(14)
        deadlineLabel.textColor = Theme.inkSecondary
        deadlineLabel.numberOfLines = 0
        for label in [nameLabel, moneyLabel, percentLabel, deadlineLabel] {
            label.adjustsFontForContentSizeCategory = true
        }
        for slot in [headerSlot, footerSlot] {
            slot.axis = .horizontal
            slot.setContentHuggingPriority(.required, for: .horizontal)
        }

        headerRow = AdaptiveRow([nameLabel, headerSlot])
        moneyRow = AdaptiveRow([moneyLabel, percentLabel])
        footerRow = AdaptiveRow([deadlineLabel, footerSlot])

        let stack = UIStackView(arrangedSubviews: [headerRow, moneyRow, bar, footerRow])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: topAnchor),
            card.bottomAnchor.constraint(equalTo: bottomAnchor),
            card.leadingAnchor.constraint(equalTo: leadingAnchor),
            card.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    func configure(_ model: GoalCardModel) {
        nameLabel.text = model.name
        moneyLabel.attributedText = Self.money(saved: model.savedText, target: model.targetText)
        let hasDeadline = model.deadlineText != nil
        let progress = model.progress.isFinite ? max(0, min(1, model.progress)) : 0
        let percent = progress < 1 ? min(99, Int((progress * 100).rounded())) : 100
        percentLabel.text = hasDeadline || model.fillsFirst ? "\(percent)%" : "Fills after dated goals"
        deadlineLabel.text = model.deadlineText
        deadlineLabel.isHidden = !hasDeadline

        headerSlot.arrangedSubviews.forEach { $0.removeFromSuperview() }
        footerSlot.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if model.fillsFirst {
            headerSlot.addArrangedSubview(TagLabel(text: "Fills first", style: .fillsFirst))
        } else if !hasDeadline {
            headerSlot.addArrangedSubview(TagLabel(text: "No deadline", style: .neutral))
        }
        if model.extended { footerSlot.addArrangedSubview(TagLabel(text: "Extended", style: .extended)) }
        headerSlot.isHidden = headerSlot.arrangedSubviews.isEmpty
        footerSlot.isHidden = footerSlot.arrangedSubviews.isEmpty
        footerRow.isHidden = !hasDeadline && !model.extended
        bar.setProgress(model.progress)
        accessibilityLabel = model.accessibilityLabel
    }

    private static func money(saved: String, target: String) -> NSAttributedString {
        let result = NSMutableAttributedString(
            string: saved,
            attributes: [.font: ThawFont.money(16), .foregroundColor: Theme.ink]
        )
        result.append(NSAttributedString(
            string: " of \(target)",
            attributes: [.font: ThawFont.money(16, weight: .regular), .foregroundColor: Theme.inkSecondary]
        ))
        return result
    }
}

/// Frost card showing the month's pending pool.
final class PendingPoolView: UIView {
    private let amountLabel = UILabel()
    private let detailLabel = UILabel()
    private let icon = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.frost
        layer.cornerRadius = Theme.Radius.card
        layer.borderWidth = 1
        layer.borderColor = Theme.frostBorder.cgColor

        icon.image = UIImage(systemName: "clock", withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold))
        icon.tintColor = Theme.frostText
        icon.contentMode = .scaleAspectFit
        icon.isAccessibilityElement = false
        icon.setContentHuggingPriority(.required, for: .horizontal)
        icon.setContentCompressionResistancePriority(.required, for: .horizontal)
        amountLabel.font = ThawFont.body(16, weight: .bold)
        amountLabel.textColor = Theme.ink
        detailLabel.font = ThawFont.body(14)
        detailLabel.textColor = Theme.toggleText
        for label in [amountLabel, detailLabel] {
            label.numberOfLines = 0
            label.adjustsFontForContentSizeCategory = true
        }
        let text = UIStackView(arrangedSubviews: [amountLabel, detailLabel])
        text.axis = .vertical
        text.spacing = 4
        let row = AdaptiveRow([icon, text])
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
        ])
        isAccessibilityElement = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(amountText: String, detail: String?) {
        amountLabel.text = "\(amountText) pending"
        detailLabel.text = detail ?? "Lands in goals at month end."
        accessibilityLabel = "\(amountLabel.text ?? ""). \(detailLabel.text ?? "")"
    }
}
