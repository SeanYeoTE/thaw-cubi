import UIKit

/// Fun money card shared by the batch review and the single decision.
final class ReviewMeterCardView: UIView {
    private let captionLabel = UILabel()
    private let amountLabel = UILabel()
    private let statusLabel = UILabel()
    private let meter = FunMoneyMeterView(fraction: 0, isOver: false)

    init(caption: String, amount: String) {
        super.init(frame: .zero)
        backgroundColor = Theme.paydayCard
        layer.cornerRadius = 20

        captionLabel.text = caption
        captionLabel.font = ThawFont.body(14)
        captionLabel.adjustsFontForContentSizeCategory = true
        captionLabel.textColor = Theme.paydayLabel
        amountLabel.text = amount
        amountLabel.font = ThawFont.money(24, weight: .heavy)
        amountLabel.adjustsFontForContentSizeCategory = true
        amountLabel.textColor = .white
        amountLabel.setContentHuggingPriority(.required, for: .horizontal)
        statusLabel.font = ThawFont.body(15, weight: .semibold)
        statusLabel.adjustsFontForContentSizeCategory = true
        for label in [captionLabel, amountLabel, statusLabel] {
            label.numberOfLines = 0
            label.adjustsFontForContentSizeCategory = true
        }

        let top = AdaptiveStackView(arrangedSubviews: [captionLabel, amountLabel])
        top.compactAlignment = .firstBaseline
        top.spacing = 8
        let inner = UIStackView(arrangedSubviews: [top, meter, statusLabel])
        inner.axis = .vertical
        inner.spacing = 10
        inner.translatesAutoresizingMaskIntoConstraints = false
        addSubview(inner)
        NSLayoutConstraint.activate([
            inner.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            inner.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            inner.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            inner.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
        ])
        isAccessibilityElement = true
        accessibilityIdentifier = "review.meter"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func update(fraction: Double, isOver: Bool, statusText: String, animated: Bool) {
        meter.update(fraction: fraction, isOver: isOver, animated: animated)
        statusLabel.textColor = isOver ? Theme.paydaySubtext : Theme.cubeFill
        statusLabel.text = statusText
        accessibilityLabel = [captionLabel.text, amountLabel.text, statusText].compactMap { $0 }.joined(separator: ", ")
    }
}
