import UIKit

final class PaydayNotificationViewController: UIViewController {
    private let store: WantStore

    init(store: WantStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background

        let thawing = store.cooling.filter { !$0.isUnderTimerThreshold }
        let total = thawing.reduce(Decimal(0)) { $0 + $1.price }

        let card = CardView()
        let icon = CubeIconView()
        let app = UILabel()
        app.text = "Thaw · now"
        app.font = ThawFont.body(13, weight: .medium)
        app.textColor = Theme.inkSecondary
        let title = UILabel()
        title.text = "Payday. \(thawing.count) wants have thawed."
        title.font = ThawFont.display(24)
        title.textColor = Theme.ink
        title.numberOfLines = 0
        let body = UILabel()
        body.text = "\(Formatting.sgd(total)) thawed. Your fun money is \(Formatting.sgd(store.payday.funMoney)). Pick what fits before the money goes elsewhere."
        body.font = ThawFont.body(15)
        body.textColor = Theme.inkSecondary
        body.numberOfLines = 0

        let text = UIStackView(arrangedSubviews: [app, title, body])
        text.axis = .vertical
        text.spacing = 6
        let row = UIStackView(arrangedSubviews: [icon, text])
        row.alignment = .top
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

        let stack = UIStackView(arrangedSubviews: [card, review, later])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Theme.Spacing.screen),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Theme.Spacing.screen),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    private func startReview() {
        let thawing = store.cooling.filter { !$0.isUnderTimerThreshold }
        guard !thawing.isEmpty else { return dismiss(animated: true) }
        let review = StillWantItViewController(store: store, queue: thawing)
        let nav = UINavigationController(rootViewController: review)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }
}
