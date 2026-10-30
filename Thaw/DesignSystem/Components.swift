import UIKit

final class ProgressBarView: UIView {
    private let fill = UIView()
    private var fillWidth: NSLayoutConstraint?

    init(fraction: CGFloat, color: UIColor) {
        super.init(frame: .zero)
        backgroundColor = Theme.track
        layer.cornerRadius = 3
        clipsToBounds = true
        fill.backgroundColor = color
        fill.translatesAutoresizingMaskIntoConstraints = false
        addSubview(fill)
        let width = fill.widthAnchor.constraint(equalTo: widthAnchor, multiplier: max(0, min(1, fraction)))
        fillWidth = width
        NSLayoutConstraint.activate([
            fill.leadingAnchor.constraint(equalTo: leadingAnchor),
            fill.topAnchor.constraint(equalTo: topAnchor),
            fill.bottomAnchor.constraint(equalTo: bottomAnchor),
            width,
        ])
        heightAnchor.constraint(equalToConstant: 6).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}

final class CardView: UIView {
    init() {
        super.init(frame: .zero)
        backgroundColor = Theme.surface
        layer.cornerRadius = Theme.Radius.card
        layer.borderWidth = 1
        layer.borderColor = Theme.border.cgColor
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}

final class PillButton: UIButton {
    enum Style { case primary, secondary, quiet }

    init(title: String, style: Style) {
        super.init(frame: .zero)
        var config: UIButton.Configuration
        switch style {
        case .primary:
            config = .filled()
            config.baseBackgroundColor = Theme.accent
            config.baseForegroundColor = .white
        case .secondary:
            config = .filled()
            config.baseBackgroundColor = Theme.surface
            config.baseForegroundColor = Theme.ink
            config.background.strokeColor = Theme.border
            config.background.strokeWidth = 1
        case .quiet:
            config = .plain()
            config.baseForegroundColor = Theme.inkSecondary
        }
        config.title = title
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var updated = attributes
            updated.font = ThawFont.body(16, weight: .semibold)
            return updated
        }
        configuration = config
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}

final class PaydayCardView: UIControl {
    private let row = UIStackView()

    init(daysLeft: Int, nextPayday: String, subtitle: String) {
        super.init(frame: .zero)
        backgroundColor = Theme.paydayCard
        layer.cornerRadius = Theme.Radius.pill

        let cubi = CubiView(mood: .frozen, size: 64)
        cubi.setContentHuggingPriority(.required, for: .horizontal)
        cubi.setContentCompressionResistancePriority(.required, for: .horizontal)
        let label = UILabel()
        label.text = "Next payday · \(nextPayday)"
        label.font = ThawFont.body(14)
        label.textColor = Theme.paydayLabel
        label.numberOfLines = 0

        let days = UILabel()
        days.text = daysLeft == 1 ? "1 day" : "\(daysLeft) days"
        days.font = ThawFont.display(34)
        days.textColor = .white
        days.numberOfLines = 0

        let sub = UILabel()
        sub.text = subtitle
        sub.font = ThawFont.body(14)
        sub.textColor = Theme.paydaySubtext
        sub.numberOfLines = 0

        for item in [label, days, sub] { item.adjustsFontForContentSizeCategory = true }

        let text = UIStackView(arrangedSubviews: [label, days, sub])
        text.axis = .vertical
        text.spacing = 2

        row.addArrangedSubview(cubi)
        row.addArrangedSubview(text)
        row.spacing = 16
        row.translatesAutoresizingMaskIntoConstraints = false
        row.isUserInteractionEnabled = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18),
        ])
        updateAxis()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: PaydayCardView, _) in
            self.updateAxis()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // Stack the face above the text at accessibility sizes.
    private func updateAxis() {
        let large = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        row.axis = large ? .vertical : .horizontal
        row.alignment = large ? .leading : .center
    }
}

final class CubeIconView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 64).isActive = true
        heightAnchor.constraint(equalToConstant: 68).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func draw(_ rect: CGRect) {
        let scale = rect.width / 160
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * scale, y: y * scale) }
        let body = UIBezierPath()
        body.move(to: p(48, 24)); body.addLine(to: p(114, 24)); body.addLine(to: p(122, 36))
        body.addLine(to: p(140, 42)); body.addLine(to: p(140, 116))
        body.addQuadCurve(to: p(112, 144), controlPoint: p(140, 144))
        body.addLine(to: p(48, 144))
        body.addQuadCurve(to: p(20, 116), controlPoint: p(20, 144))
        body.addLine(to: p(20, 52))
        body.addQuadCurve(to: p(48, 24), controlPoint: p(20, 24))
        body.close()
        Theme.cubeFill.setFill()
        body.fill()
        Theme.cubeStroke.setStroke()
        body.lineWidth = 7 * scale
        body.lineJoinStyle = .round
        body.stroke()

        let eyes = UIBezierPath()
        eyes.move(to: p(53, 86)); eyes.addLine(to: p(71, 86))
        eyes.move(to: p(89, 86)); eyes.addLine(to: p(107, 86))
        eyes.lineWidth = 8 * scale
        eyes.lineCapStyle = .round
        Theme.ink.setStroke()
        eyes.stroke()

        let mouth = UIBezierPath()
        mouth.move(to: p(62, 112))
        for x in stride(from: 68, through: 98, by: 6) {
            mouth.addLine(to: p(CGFloat(x), x.isMultiple(of: 12) ? 112 : 107))
        }
        mouth.lineWidth = 6 * scale
        mouth.lineCapStyle = .round
        mouth.lineJoinStyle = .round
        Theme.ink.setStroke()
        mouth.stroke()
    }
}

/// Radio row: title and hint with a ring dot. Set `isSelected` from the owner.
final class ChoiceRowView: UIControl {
    private let dot = UIView()
    private let titleLabel = UILabel()
    private let hintLabel = UILabel()

    init(title: String, hint: String, selected: Bool) {
        super.init(frame: .zero)
        backgroundColor = Theme.surface
        layer.cornerRadius = Theme.Radius.card

        titleLabel.text = title
        titleLabel.font = ThawFont.body(16, weight: .semibold)
        titleLabel.textColor = Theme.ink
        hintLabel.text = hint
        hintLabel.font = ThawFont.body(13)
        hintLabel.textColor = Theme.inkSecondary
        for label in [titleLabel, hintLabel] {
            label.numberOfLines = 0
            label.adjustsFontForContentSizeCategory = true
        }

        dot.layer.cornerRadius = 10
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.isUserInteractionEnabled = false
        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: 20),
            dot.heightAnchor.constraint(equalToConstant: 20),
        ])

        let text = UIStackView(arrangedSubviews: [titleLabel, hintLabel])
        text.axis = .vertical
        text.spacing = 2
        let row = UIStackView(arrangedSubviews: [dot, text])
        row.alignment = .center
        row.spacing = 14
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 54),
        ])

        isAccessibilityElement = true
        accessibilityLabel = title
        accessibilityValue = hint
        isSelected = selected
        applySelection()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: ChoiceRowView, _) in
            self.applySelection()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isSelected: Bool {
        didSet { applySelection() }
    }

    private func applySelection() {
        layer.borderWidth = isSelected ? 2 : 1
        layer.borderColor = (isSelected ? Theme.accent : Theme.border).cgColor
        dot.layer.borderWidth = isSelected ? 6 : 2
        dot.layer.borderColor = (isSelected ? Theme.accent : Theme.radioDot).cgColor
        accessibilityTraits = isSelected ? [.button, .selected] : .button
    }
}

/// "Keep" / "Wait" pill. Toggles itself on tap and sends `.valueChanged`.
final class KeepToggleButton: UIButton {
    var name: String = "" {
        didSet { updateAccessibility() }
    }

    var isKeeping: Bool {
        didSet { applyState() }
    }

    init(isKeeping: Bool) {
        self.isKeeping = isKeeping
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(greaterThanOrEqualToConstant: 64),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
        ])
        addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.isKeeping.toggle()
            self.sendActions(for: .valueChanged)
        }, for: .touchUpInside)
        applyState()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func applyState() {
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .capsule
        config.title = isKeeping ? "Keep" : "Wait"
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
        if isKeeping {
            config.baseBackgroundColor = Theme.accent
            config.baseForegroundColor = .white
            config.background.strokeWidth = 0
        } else {
            config.baseBackgroundColor = Theme.surface
            config.baseForegroundColor = Theme.toggleText
            config.background.strokeColor = Theme.toggleBorder
            config.background.strokeWidth = 1
        }
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var updated = attributes
            updated.font = ThawFont.body(15, weight: .bold)
            return updated
        }
        configuration = config
        titleLabel?.adjustsFontForContentSizeCategory = true
        updateAccessibility()
    }

    private func updateAccessibility() {
        accessibilityLabel = name.isEmpty
            ? (isKeeping ? "Keeping" : "Waiting")
            : (isKeeping ? "Keeping \(name)" : "Waiting on \(name)")
        accessibilityTraits = isKeeping ? [.button, .selected] : .button
    }
}

/// 10pt bar: icy blue under budget, warm when over.
final class FunMoneyMeterView: UIView {
    private let fill = UIView()
    private var fillWidth: NSLayoutConstraint?
    private var fraction: CGFloat

    init(fraction: Double, isOver: Bool) {
        self.fraction = Self.clamp(fraction)
        super.init(frame: .zero)
        backgroundColor = Theme.meterTrack
        layer.cornerRadius = 5
        clipsToBounds = true
        fill.layer.cornerRadius = 5
        fill.translatesAutoresizingMaskIntoConstraints = false
        addSubview(fill)
        NSLayoutConstraint.activate([
            fill.leadingAnchor.constraint(equalTo: leadingAnchor),
            fill.topAnchor.constraint(equalTo: topAnchor),
            fill.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalToConstant: 10),
        ])
        applyWidth()
        fill.backgroundColor = isOver ? Theme.warm : Theme.cubeStroke
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func update(fraction: Double, isOver: Bool, animated: Bool) {
        self.fraction = Self.clamp(fraction)
        let color = isOver ? Theme.warm : Theme.cubeStroke
        applyWidth()
        let changes = {
            self.fill.backgroundColor = color
            self.layoutIfNeeded()
        }
        if animated, !UIAccessibility.isReduceMotionEnabled {
            UIView.animate(withDuration: 0.25, animations: changes)
        } else {
            changes()
        }
    }

    private static func clamp(_ value: Double) -> CGFloat {
        value.isFinite ? CGFloat(max(0, min(1, value))) : 0
    }

    private func applyWidth() {
        fillWidth?.isActive = false
        let width = fill.widthAnchor.constraint(equalTo: widthAnchor, multiplier: max(fraction, 0.0001))
        width.isActive = true
        fillWidth = width
    }
}

/// Settings line: title and optional hint on the left, accent value on the right.
final class SettingsRowView: UIView {
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let valueLabel = UILabel()
    private let row = UIStackView()

    var value: String {
        get { valueLabel.text ?? "" }
        set { valueLabel.text = newValue; updateAccessibility() }
    }

    init(title: String, subtitle: String?, value: String) {
        super.init(frame: .zero)
        titleLabel.text = title
        titleLabel.font = ThawFont.body(16)
        titleLabel.textColor = Theme.ink
        subtitleLabel.text = subtitle
        subtitleLabel.font = ThawFont.body(13)
        subtitleLabel.textColor = Theme.inkSecondary
        subtitleLabel.isHidden = (subtitle ?? "").isEmpty
        valueLabel.text = value
        valueLabel.font = ThawFont.body(16, weight: .semibold)
        valueLabel.textColor = Theme.accent
        valueLabel.textAlignment = .right
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        for label in [titleLabel, subtitleLabel, valueLabel] {
            label.numberOfLines = 0
            label.adjustsFontForContentSizeCategory = true
        }

        let text = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        text.axis = .vertical
        text.spacing = 2
        row.addArrangedSubview(text)
        row.addArrangedSubview(valueLabel)
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        let minHeight = (subtitle ?? "").isEmpty ? 48.0 : 58.0
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            heightAnchor.constraint(greaterThanOrEqualToConstant: minHeight),
        ])
        updateAxis()
        isAccessibilityElement = true
        updateAccessibility()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: SettingsRowView, _) in
            self.updateAxis()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // Stack the value under the title at accessibility sizes.
    private func updateAxis() {
        let large = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        row.axis = large ? .vertical : .horizontal
        row.alignment = large ? .leading : .center
        valueLabel.textAlignment = large ? .left : .right
    }

    private func updateAccessibility() {
        accessibilityLabel = [titleLabel.text, subtitleLabel.text].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
        accessibilityValue = valueLabel.text
    }
}
