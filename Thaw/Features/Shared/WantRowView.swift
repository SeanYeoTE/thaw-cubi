import UIKit

/// Two-line card: title and price, then status and trailing caption. Both lines use the full row width and
/// stack vertically at accessibility sizes. Progress is a strip on the card's bottom edge so rows stay short.
final class WantRowView: UIView {
    private static let stripHeight: CGFloat = 4

    init(model: WantRowModel) {
        super.init(frame: .zero)
        let card = CardView()
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)

        let title = Self.label(model.title, font: ThawFont.body(16, weight: .semibold), color: Theme.ink)
        title.numberOfLines = 2
        let price = Self.label(model.priceText, font: ThawFont.money(16), color: Theme.ink)
        price.setContentHuggingPriority(.required, for: .horizontal)
        price.setContentCompressionResistancePriority(.required, for: .horizontal)
        price.textAlignment = .right

        let status = Self.label(model.status, font: ThawFont.body(13), color: Self.color(model.statusTone))
        let trailing = Self.label(model.trailing ?? "", font: ThawFont.body(13), color: Theme.inkSecondary)
        trailing.setContentHuggingPriority(.required, for: .horizontal)
        trailing.setContentCompressionResistancePriority(.required, for: .horizontal)
        trailing.textAlignment = .right
        trailing.isHidden = model.trailing == nil

        let top = AdaptiveStackView(arrangedSubviews: [title, price])
        top.compactAlignment = .firstBaseline
        top.spacing = 12
        let bottom = AdaptiveStackView(arrangedSubviews: [status, trailing])
        bottom.compactAlignment = .firstBaseline
        bottom.spacing = 12

        let stack = UIStackView(arrangedSubviews: [top, bottom])
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        let stripInset: CGFloat = model.progress == nil ? 0 : Self.stripHeight
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: leadingAnchor),
            card.trailingAnchor.constraint(equalTo: trailingAnchor),
            card.topAnchor.constraint(equalTo: topAnchor),
            card.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -(12 + stripInset)),
        ])

        if let progress = model.progress {
            let track = UIView()
            track.backgroundColor = Theme.track
            track.translatesAutoresizingMaskIntoConstraints = false
            let fill = UIView()
            fill.backgroundColor = Self.color(model.progressTone)
            fill.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(track)
            track.addSubview(fill)
            let fraction = CGFloat(min(max(progress, 0), 1))
            NSLayoutConstraint.activate([
                track.leadingAnchor.constraint(equalTo: card.leadingAnchor),
                track.trailingAnchor.constraint(equalTo: card.trailingAnchor),
                track.bottomAnchor.constraint(equalTo: card.bottomAnchor),
                track.heightAnchor.constraint(equalToConstant: Self.stripHeight),
                fill.leadingAnchor.constraint(equalTo: track.leadingAnchor),
                fill.topAnchor.constraint(equalTo: track.topAnchor),
                fill.bottomAnchor.constraint(equalTo: track.bottomAnchor),
                fill.widthAnchor.constraint(equalTo: track.widthAnchor, multiplier: max(fraction, 0.0001)),
            ])
        }

        isAccessibilityElement = true
        accessibilityLabel = model.accessibilityLabel
        accessibilityValue = model.accessibilityValue
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private static func label(_ text: String, font: UIFont, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = color
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        return label
    }

    private static func color(_ tone: WantRowTone) -> UIColor {
        switch tone {
        case .neutral: Theme.inkSecondary
        case .accent: Theme.accent
        case .timer: Theme.warm
        }
    }
}
