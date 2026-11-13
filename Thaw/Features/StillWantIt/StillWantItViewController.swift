import UIKit

/// One-want-at-a-time decision, reached from Item detail.
final class StillWantItViewController: ScrollStackViewController, StillWantItViewProtocol {
    var presenter: StillWantItPresenterProtocol?

    private let progressLabel = UILabel()
    private let name = UILabel()
    private let price = UILabel()
    private let quote = UILabel()
    private let dateLabel = UILabel()
    private var meterCard: ReviewMeterCardView?
    private let letGo = PillButton(title: "", style: .primary)
    private let buy = PillButton(title: "Buy it", style: .secondary)
    private let wait = PillButton(title: "Wait a payday", style: .quiet)

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func buildContent() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeTapped))
        stack.spacing = 14

        progressLabel.font = ThawFont.body(13, weight: .medium)
        progressLabel.adjustsFontForContentSizeCategory = true
        progressLabel.textColor = Theme.inkSecondary
        name.font = ThawFont.display(28)
        name.adjustsFontForContentSizeCategory = true
        name.textColor = Theme.ink
        price.font = ThawFont.money(20)
        price.adjustsFontForContentSizeCategory = true
        price.textColor = Theme.ink
        quote.font = ThawFont.body(17)
        quote.adjustsFontForContentSizeCategory = true
        quote.textColor = Theme.ink
        dateLabel.font = ThawFont.body(13)
        dateLabel.adjustsFontForContentSizeCategory = true
        dateLabel.textColor = Theme.inkSecondary
        for label in [progressLabel, name, price, quote, dateLabel] {
            label.numberOfLines = 0
            label.adjustsFontForContentSizeCategory = true
        }

        let card = CardView()
        let inner = UIStackView(arrangedSubviews: [progressLabel, name, price, quote, dateLabel])
        inner.axis = .vertical
        inner.spacing = 8
        inner.setCustomSpacing(14, after: price)
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            inner.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
        ])

        letGo.accessibilityIdentifier = "decide.letGo"
        buy.accessibilityIdentifier = "decide.buy"
        wait.accessibilityIdentifier = "decide.wait"
        letGo.addAction(UIAction { [weak self] _ in self?.presenter?.tapLetGo() }, for: .touchUpInside)
        buy.addAction(UIAction { [weak self] _ in self?.presenter?.tapBuy() }, for: .touchUpInside)
        wait.addAction(UIAction { [weak self] _ in self?.presenter?.tapWait() }, for: .touchUpInside)

        [card, letGo, buy, wait].forEach(stack.addArrangedSubview)
        stack.setCustomSpacing(18, after: card)
        presenter?.viewDidLoad()
    }

    func render(_ model: StillWantItViewModel) {
        progressLabel.text = model.progressText
        progressLabel.isHidden = model.progressText.isEmpty
        name.text = model.name
        price.text = model.priceText
        quote.text = model.quote
        dateLabel.text = model.dateText
        name.accessibilityTraits = .header
        price.accessibilityLabel = model.priceText
        dateLabel.accessibilityLabel = "Written on \(model.dateText)"

        // The meter card is rebuilt per want because its budget text is fixed at creation.
        meterCard?.removeFromSuperview()
        let card = ReviewMeterCardView(caption: model.budgetCaption, amount: model.budgetText)
        card.update(fraction: model.meterFraction, isOver: model.meterIsOver, statusText: model.meterText, animated: false)
        stack.insertArrangedSubview(card, at: 1)
        meterCard = card

        letGo.configuration?.title = model.letGoTitle
        buy.configuration?.title = model.buyTitle
        wait.configuration?.title = model.waitTitle
    }

    func showSkipMoment(line: String, completion: @escaping () -> Void) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        navigationController?.setNavigationBarHidden(true, animated: true)
        MomentView.present(on: view, mood: .proud, line: line) { [weak self] in
            self?.navigationController?.setNavigationBarHidden(false, animated: false)
            completion()
        }
    }

    func setActionsEnabled(_ enabled: Bool) {
        for button in [letGo, buy, wait] { button.isEnabled = enabled }
    }

    @objc private func closeTapped() {
        presenter?.tapClose()
    }

    override func accessibilityPerformEscape() -> Bool {
        closeTapped()
        return true
    }
}
