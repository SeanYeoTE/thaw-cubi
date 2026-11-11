import UIKit

/// Compact stat: an SF Symbol, a value and an optional 1-to-2-word caption (`flame.fill` "3" "streak").
/// A `UIControl`, so callers can attach a tap that explains the figure; doing so adds the `.button` trait.
final class StatChipView: UIControl {
    private let valueLabel = UILabel()
    private let captionLabel = UILabel()
    private let symbolView = UIImageView()

    init(symbol: String?, value: String, caption: String?, spoken: String) {
        super.init(frame: .zero)
        backgroundColor = Theme.surface
        layer.cornerRadius = Theme.Radius.pill
        layer.borderWidth = 1
        layer.borderColor = Theme.border.cgColor

        symbolView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(font: ThawFont.body(15, weight: .semibold))
        symbolView.adjustsImageSizeForAccessibilityContentSizeCategory = true
        symbolView.tintColor = Theme.accent
        symbolView.contentMode = .scaleAspectFit
        symbolView.setContentHuggingPriority(.required, for: .horizontal)
        symbolView.setContentCompressionResistancePriority(.required, for: .horizontal)

        valueLabel.font = ThawFont.money(17)
        valueLabel.textColor = Theme.ink
        captionLabel.font = ThawFont.body(13)
        captionLabel.textColor = Theme.inkSecondary
        for label in [valueLabel, captionLabel] {
            label.numberOfLines = 0
            label.adjustsFontForContentSizeCategory = true
        }
        // Values and 1-to-2-word captions never break mid-word; at accessibility sizes the row stacks instead.
        for label in [valueLabel, captionLabel] {
            label.setContentHuggingPriority(.required, for: .horizontal)
            label.setContentCompressionResistancePriority(.required, for: .horizontal)
        }

        let row = AdaptiveStackView(arrangedSubviews: [symbolView, valueLabel, captionLabel])
        row.compactAlignment = .center
        row.spacing = 6
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
        ])

        isAccessibilityElement = true
        accessibilityTraits = .staticText
        configure(symbol: symbol, value: value, caption: caption, spoken: spoken)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(symbol: String?, value: String, caption: String?, spoken: String) {
        symbolView.image = symbol.flatMap { UIImage(systemName: $0) }
        symbolView.isHidden = symbolView.image == nil
        valueLabel.text = value
        captionLabel.text = caption
        captionLabel.isHidden = caption?.isEmpty ?? true
        accessibilityLabel = spoken
    }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.6 : 1 }
    }

    override func addTarget(_ target: Any?, action: Selector, for controlEvents: UIControl.Event) {
        super.addTarget(target, action: action, for: controlEvents)
        accessibilityTraits = .button
    }

    override func addAction(_ action: UIAction, for controlEvents: UIControl.Event) {
        super.addAction(action, for: controlEvents)
        accessibilityTraits = .button
    }
}
