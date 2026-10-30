import UIKit

final class PaydayNotificationViewController: ScrollStackViewController {
    private let store: WantStore
    private let reminders: Reminders

    init(store: WantStore, reminders: Reminders) {
        self.store = store
        self.reminders = reminders
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func buildContent() {
        stack.spacing = 12

        let thawing = store.reviewQueue
        let total = thawing.reduce(Decimal(0)) { $0 + $1.price }

        let card = CardView()
        let icon = AppIconBadgeView()
        let app = UILabel()
        app.text = "Thaw · now"
        app.font = ThawFont.body(13, weight: .medium)
        app.textColor = Theme.inkSecondary
        app.adjustsFontForContentSizeCategory = true
        let title = UILabel()
        title.text = ThawNotification.paydayTitle(count: thawing.count)
        title.font = ThawFont.display(24)
        title.textColor = Theme.ink
        title.numberOfLines = 0
        title.adjustsFontForContentSizeCategory = true
        let body = UILabel()
        body.text = ThawNotification.paydayBody(total: total, funMoney: store.effectiveSettings.funMoney)
        body.font = ThawFont.body(15)
        body.textColor = Theme.inkSecondary
        body.numberOfLines = 0
        body.adjustsFontForContentSizeCategory = true

        let text = UIStackView(arrangedSubviews: [app, title, body])
        text.axis = .vertical
        text.spacing = 6
        let row = AdaptiveStackView(arrangedSubviews: [icon, text])
        row.compactAlignment = .top
        row.spacing = 14
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
        ])

        let review = PillButton(title: "Review now", style: .primary)
        review.addAction(UIAction { [weak self] _ in self?.startReview() }, for: .touchUpInside)
        let later = PillButton(title: "Remind me tonight", style: .quiet)
        later.addAction(UIAction { [weak self] _ in self?.dismiss(animated: true) }, for: .touchUpInside)

        [card, review, later].forEach(stack.addArrangedSubview)
    }

    private func startReview() {
        let thawing = store.reviewQueue
        guard !thawing.isEmpty else { return dismiss(animated: true) }
        let review = PaydayReviewViewController(store: store, reminders: reminders, wants: thawing)
        let nav = UINavigationController(rootViewController: review)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }
}

/// Stand-in for the app icon in the notification preview: dark ground, chip and two eyes.
private final class AppIconBadgeView: UIView {
    init() {
        super.init(frame: .zero)
        backgroundColor = Theme.paydayCard
        layer.cornerRadius = 11
        isAccessibilityElement = false
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 44).isActive = true
        heightAnchor.constraint(equalToConstant: 44).isActive = true
        let eyes = UIStackView()
        eyes.spacing = 8
        for _ in 0..<2 {
            let eye = UIView()
            eye.backgroundColor = Theme.cubeFill
            eye.layer.cornerRadius = 2
            eye.widthAnchor.constraint(equalToConstant: 9).isActive = true
            eye.heightAnchor.constraint(equalToConstant: 4).isActive = true
            eyes.addArrangedSubview(eye)
        }
        eyes.translatesAutoresizingMaskIntoConstraints = false
        addSubview(eyes)
        NSLayoutConstraint.activate([
            eyes.centerXAnchor.constraint(equalTo: centerXAnchor),
            eyes.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}
