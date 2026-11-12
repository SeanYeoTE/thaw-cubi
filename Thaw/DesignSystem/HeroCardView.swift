import UIKit

/// The dark card that leads a hero screen (Payday, Stats). Cubi sits on it at `CubiSize.card`.
final class HeroCardView: UIView {
    static let padding: CGFloat = 18

    init(content: UIView) {
        super.init(frame: .zero)
        backgroundColor = Theme.paydayCard
        layer.cornerRadius = Theme.Radius.pill
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        let pad = Self.padding
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: pad),
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -pad),
            content.topAnchor.constraint(equalTo: topAnchor, constant: pad),
            content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -pad),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}
