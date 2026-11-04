import UIKit

final class PaydayPreviewViewController: ScrollStackViewController, PaydayPreviewViewProtocol {
    var presenter: PaydayPreviewPresenterProtocol?
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()
    private let remindButton = PillButton(title: "Remind me tonight", style: .quiet)

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func buildContent() {
        title = "Payday preview"
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in
            self?.closeTapped()
        })
        stack.spacing = 12

        let card = CardView()
        let icon = AppIconBadgeView()
        let app = UILabel()
        app.text = "Thaw · now"
        app.font = ThawFont.body(13, weight: .medium)
        app.textColor = Theme.inkSecondary
        app.adjustsFontForContentSizeCategory = true
        let title = titleLabel
        title.font = ThawFont.display(24)
        title.textColor = Theme.ink
        title.numberOfLines = 0
        title.adjustsFontForContentSizeCategory = true
        let body = bodyLabel
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
        review.addAction(UIAction { [weak self] _ in self?.presenter?.tapReview() }, for: .touchUpInside)
        remindButton.addAction(UIAction { [weak self] _ in self?.presenter?.tapRemindTonight() }, for: .touchUpInside)

        [card, review, remindButton].forEach(stack.addArrangedSubview)
        presenter?.viewDidLoad()
    }

    func render(_ model: PaydayPreviewViewModel) {
        titleLabel.text = model.title
        bodyLabel.text = model.body
    }

    func setReminderBusy() {
        remindButton.isEnabled = false
    }

    func playSuccessFeedback() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func closeTapped() {
        presenter?.tapClose()
    }

    override func accessibilityPerformEscape() -> Bool {
        closeTapped()
        return true
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
