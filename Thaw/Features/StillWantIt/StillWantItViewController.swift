import UIKit

/// One-want-at-a-time decision, reached from Item detail.
final class StillWantItViewController: ScrollStackViewController, StillWantItViewProtocol {
    var presenter: StillWantItPresenterProtocol?

    private let progressLabel = UILabel()
    private let question = UILabel()
    private let price = UILabel()
    private let quote = UILabel()
    private let funLabel = UILabel()
    private let keep = PillButton(title: "", style: .secondary)
    private let buy = PillButton(title: "Yes, I'll buy it", style: .primary)
    private let unsure = PillButton(title: "Not sure? Wait one more payday", style: .quiet)

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func buildContent() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeTapped))
        stack.spacing = 14

        progressLabel.font = ThawFont.body(13, weight: .medium)
        progressLabel.textColor = Theme.inkSecondary
        question.font = ThawFont.display(28)
        question.textColor = Theme.ink
        price.font = ThawFont.money(20)
        price.textColor = Theme.ink
        quote.font = ThawFont.body(16)
        quote.textColor = Theme.inkSecondary
        funLabel.font = ThawFont.body(15)
        funLabel.textColor = Theme.inkSecondary
        for label in [progressLabel, question, price, quote, funLabel] {
            label.numberOfLines = 0
            label.adjustsFontForContentSizeCategory = true
        }

        let card = CardView()
        let inner = UIStackView(arrangedSubviews: [progressLabel, question, price, quote])
        inner.axis = .vertical
        inner.spacing = 10
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            inner.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
        ])

        keep.addAction(UIAction { [weak self] _ in self?.presenter?.tapSkip() }, for: .touchUpInside)
        buy.addAction(UIAction { [weak self] _ in self?.presenter?.tapBuy() }, for: .touchUpInside)
        unsure.addAction(UIAction { [weak self] _ in self?.presenter?.tapWait() }, for: .touchUpInside)

        [card, funLabel, keep, buy, unsure].forEach(stack.addArrangedSubview)
        stack.setCustomSpacing(18, after: funLabel)
        presenter?.viewDidLoad()
    }

    func render(_ model: StillWantItViewModel) {
        progressLabel.text = model.progressText
        question.text = model.question
        price.text = model.priceText
        quote.text = model.quote
        funLabel.text = model.funText
        keep.configuration?.title = model.keepTitle
    }

    func showSkipMoment(line: String, completion: @escaping () -> Void) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        navigationController?.setNavigationBarHidden(true, animated: true)
        MomentView.present(on: view, mood: .proud, line: line) { [weak self] in
            self?.navigationController?.setNavigationBarHidden(false, animated: false)
            completion()
        }
    }

    @objc private func closeTapped() {
        presenter?.tapClose()
    }

    override func accessibilityPerformEscape() -> Bool {
        closeTapped()
        return true
    }
}
