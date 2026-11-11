import UIKit

/// Stat tile: an SF Symbol and value on one line, with a short caption underneath (`flame.fill` "3", "streak").
/// The value never wraps, so tiles in a row stay tidy; callers give the tiles equal widths.
/// A `UIControl`, so callers can attach a tap that explains the figure; doing so adds the `.button` trait.
final class StatChipView: UIControl {
    private let valueLabel = UILabel()
    private let captionLabel = UILabel()
    private let symbolView = UIImageView()
    private let valueRow = UIStackView()

    init(symbol: String?, value: String, caption: String?, spoken: String) {
        super.init(frame: .zero)
        backgroundColor = Theme.surface
        layer.cornerRadius = Theme.Radius.card
        layer.borderWidth = 1
        layer.borderColor = Theme.controlBorder.cgColor

        symbolView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(font: ThawFont.body(15, weight: .semibold))
        symbolView.adjustsImageSizeForAccessibilityContentSizeCategory = true
        symbolView.tintColor = Theme.accent
        symbolView.contentMode = .scaleAspectFit
        symbolView.setContentHuggingPriority(.required, for: .horizontal)
        symbolView.setContentCompressionResistancePriority(.required, for: .horizontal)

        valueLabel.font = ThawFont.money(20)
        valueLabel.textColor = Theme.ink
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        captionLabel.font = ThawFont.body(13)
        captionLabel.textColor = Theme.inkSecondary
        captionLabel.adjustsFontForContentSizeCategory = true
        captionLabel.numberOfLines = 0
        captionLabel.textAlignment = .center

        valueRow.addArrangedSubview(symbolView)
        valueRow.addArrangedSubview(valueLabel)
        valueRow.spacing = 6
        valueRow.alignment = .center

        let column = UIStackView(arrangedSubviews: [valueRow, captionLabel])
        column.axis = .vertical
        column.alignment = .center
        column.spacing = 2
        column.isUserInteractionEnabled = false
        column.translatesAutoresizingMaskIntoConstraints = false
        addSubview(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 10),
            column.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -10),
            column.centerXAnchor.constraint(equalTo: centerXAnchor),
            // Top-aligned, so values line up across tiles of equal height even if one caption wraps.
            column.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            column.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -10),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
        ])

        isAccessibilityElement = true
        accessibilityTraits = .staticText
        configure(symbol: symbol, value: value, caption: caption, spoken: spoken)
        updateForTextSize()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: StatChipView, _) in
            self.updateForTextSize()
        }
    }

    /// One line at standard sizes; at accessibility sizes the tiles stack full width, so the value may wrap.
    private func updateForTextSize() {
        valueLabel.numberOfLines = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? 0 : 1
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
