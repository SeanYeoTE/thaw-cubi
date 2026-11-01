import UIKit

/// Payday review: pick which thawed wants fit the fun money, Keep or Wait on each.
final class PaydayReviewViewController: ScrollStackViewController, PaydayReviewViewProtocol {
    var presenter: PaydayReviewPresenterProtocol?

    private let amountLabel = UILabel()
    private let statusLabel = UILabel()
    private let meter = FunMoneyMeterView(fraction: 0, isOver: false)
    private let cta = PillButton(title: "Wait on all", style: .primary)

    init() {
        super.init(nibName: nil, bundle: nil)
        title = "Payday review"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func buildContent() {
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeTapped))
        stack.spacing = 16
        presenter?.viewDidLoad()
    }

    func render(_ content: PaydayReviewContent) {
        stack.addArrangedSubview(CubiHeaderView(mood: .thawed, line: "Cubi: \u{201C}Pick what fits your fun money.\u{201D}",
                                              spoken: "Pick what fits your fun money."))
        stack.addArrangedSubview(makeMeterCard(budgetText: content.budgetText))

        for row in content.rows {
            stack.addArrangedSubview(makeRow(for: row))
        }

        stack.addArrangedSubview(makeLabel(
            "Anything you don't keep waits one more payday. Let go of it anytime from its page.",
            font: ThawFont.body(13), color: Theme.inkSecondary))

        cta.addAction(UIAction { [weak self] _ in self?.presenter?.tapCTA() }, for: .touchUpInside)
        stack.addArrangedSubview(cta)
    }

    private func makeMeterCard(budgetText: String) -> UIView {
        let card = UIView()
        card.backgroundColor = Theme.paydayCard
        card.layer.cornerRadius = 20

        let caption = makeLabel("Fun money this payday", font: ThawFont.body(14), color: Theme.paydayLabel)
        amountLabel.text = budgetText
        amountLabel.font = ThawFont.money(24, weight: .heavy)
        amountLabel.textColor = .white
        amountLabel.numberOfLines = 0
        amountLabel.adjustsFontForContentSizeCategory = true
        amountLabel.setContentHuggingPriority(.required, for: .horizontal)
        statusLabel.font = ThawFont.body(14, weight: .semibold)
        statusLabel.numberOfLines = 0
        statusLabel.adjustsFontForContentSizeCategory = true

        let top = AdaptiveStackView(arrangedSubviews: [caption, amountLabel])
        top.compactAlignment = .firstBaseline
        top.spacing = 8
        let inner = UIStackView(arrangedSubviews: [top, meter, statusLabel])
        inner.axis = .vertical
        inner.spacing = 10
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            inner.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])
        return card
    }

    private func makeRow(for model: ReviewRowViewModel) -> UIView {
        let card = CardView()
        let name = makeLabel(model.name, font: ThawFont.body(16, weight: .semibold))
        let reason = makeLabel(model.reasonText,
                               font: ThawFont.body(13), color: Theme.inkSecondary)
        reason.numberOfLines = 0
        let price = makeLabel(model.priceText, font: ThawFont.money(16))
        price.setContentHuggingPriority(.required, for: .horizontal)
        price.setContentCompressionResistancePriority(.required, for: .horizontal)

        let toggle = KeepToggleButton(isKeeping: model.isKeeping)
        toggle.name = model.name
        toggle.addAction(UIAction { [weak self, weak toggle] _ in
            guard let self, let toggle else { return }
            self.presenter?.setKeeping(id: model.id, keeping: toggle.isKeeping)
        }, for: .valueChanged)

        let text = UIStackView(arrangedSubviews: [name, reason])
        text.axis = .vertical
        text.spacing = 3
        let row = AdaptiveStackView(arrangedSubviews: [text, price, toggle])
        row.compactAlignment = .center
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])
        return card
    }

    func update(_ summary: PaydayReviewSummary, animated: Bool) {
        meter.update(fraction: summary.fraction, isOver: summary.isOver, animated: animated)
        statusLabel.textColor = summary.isOver ? Theme.paydaySubtext : Theme.cubeFill
        statusLabel.text = summary.statusText
        cta.configuration?.title = summary.ctaTitle
    }

    func playSuccessFeedback() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func showDiscardConfirmation() {
        let sheet = UIAlertController(title: "Discard choices?", message: "Your Keep and Wait picks won't be applied.",
                                      preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Discard", style: .destructive) { [weak self] _ in
            self?.presenter?.confirmDiscard()
        })
        sheet.addAction(UIAlertAction(title: "Keep choosing", style: .cancel))
        sheet.popoverPresentationController?.sourceItem = navigationItem.leftBarButtonItem
        present(sheet, animated: true)
    }

    @objc private func closeTapped() {
        presenter?.tapClose()
    }

    override func accessibilityPerformEscape() -> Bool {
        closeTapped()
        return true
    }
}
