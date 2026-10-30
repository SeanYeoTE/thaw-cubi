import UIKit

final class WantCardView: UIControl {
    init(want: Want, settings: PaydaySettings) {
        super.init(frame: .zero)
        let card = CardView()
        card.isUserInteractionEnabled = false
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)

        let name = UILabel()
        name.text = want.name
        name.font = ThawFont.body(16, weight: .semibold)
        name.textColor = Theme.ink
        name.numberOfLines = 0
        name.adjustsFontForContentSizeCategory = true

        let price = UILabel()
        price.text = Formatting.sgd(want.price)
        price.font = ThawFont.money(16)
        price.textColor = Theme.ink
        price.adjustsFontForContentSizeCategory = true
        price.setContentHuggingPriority(.required, for: .horizontal)
        price.setContentCompressionResistancePriority(.required, for: .horizontal)

        let header = AdaptiveStackView(arrangedSubviews: [name, price])
        header.compactAlignment = .firstBaseline
        header.spacing = 8

        let isTimer = want.price < settings.timerThreshold
        let bar = ProgressBarView(fraction: CGFloat(want.progress), color: isTimer ? Theme.warm : Theme.accent)

        let status = UILabel()
        status.font = ThawFont.body(13)
        status.textColor = Theme.inkSecondary
        status.numberOfLines = 0
        status.adjustsFontForContentSizeCategory = true
        status.text = isTimer
            ? "Under \(Formatting.sgd(settings.timerThreshold)) · \(settings.timerDays)-day timer · thaws \(Formatting.paydayDate(want.thawsAt))"
            : "Thaws on payday · \(Formatting.paydayDate(want.thawsAt))"

        let stack = UIStackView(arrangedSubviews: [header, bar, status])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: leadingAnchor),
            card.trailingAnchor.constraint(equalTo: trailingAnchor),
            card.topAnchor.constraint(equalTo: topAnchor),
            card.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}
