import UIKit

final class WantCardView: UIControl {
    init(want: Want) {
        super.init(frame: .zero)
        let card = CardView()
        card.isUserInteractionEnabled = false
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)

        let name = UILabel()
        name.text = want.name
        name.font = ThawFont.body(16, weight: .semibold)
        name.textColor = Theme.ink
        name.lineBreakMode = .byTruncatingTail

        let price = UILabel()
        price.text = Formatting.sgd(want.price)
        price.font = ThawFont.money(16)
        price.textColor = Theme.ink
        price.setContentHuggingPriority(.required, for: .horizontal)

        let header = UIStackView(arrangedSubviews: [name, price])
        header.spacing = 8

        let bar = ProgressBarView(fraction: CGFloat(want.progress),
                                  color: want.isUnderTimerThreshold ? Theme.warm : Theme.accent)

        let status = UILabel()
        status.font = ThawFont.body(13)
        status.textColor = Theme.inkSecondary
        status.numberOfLines = 0
        status.text = want.isUnderTimerThreshold
            ? "Under S$30 · 2-day timer · thaws Sun, 15 Nov"
            : "Thaws on payday"

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
