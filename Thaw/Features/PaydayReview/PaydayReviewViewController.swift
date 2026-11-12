import UIKit

/// Payday review: Keep, Wait or Let go of each thawed want against the fun money.
final class PaydayReviewViewController: ScrollStackViewController, PaydayReviewViewProtocol {
    var presenter: PaydayReviewPresenterProtocol?

    private var meterCard: ReviewMeterCardView?
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
        let card = ReviewMeterCardView(caption: content.budgetCaption, amount: content.budgetText)
        meterCard = card
        stack.addArrangedSubview(card)

        for row in content.rows {
            stack.addArrangedSubview(makeRow(for: row))
        }

        cta.accessibilityIdentifier = "review.done"
        cta.addAction(UIAction { [weak self] _ in self?.presenter?.tapCTA() }, for: .touchUpInside)
        stack.addArrangedSubview(cta)
    }

    private func makeRow(for model: ReviewRowViewModel) -> UIView {
        let card = CardView()
        card.accessibilityIdentifier = "review.row"
        let name = makeLabel(model.name, font: ThawFont.body(16, weight: .semibold))
        let price = makeLabel(model.priceText, font: ThawFont.money(16))
        price.setContentHuggingPriority(.required, for: .horizontal)
        price.setContentCompressionResistancePriority(.required, for: .horizontal)
        let heading = AdaptiveStackView(arrangedSubviews: [name, price])
        heading.compactAlignment = .firstBaseline
        heading.spacing = 12

        let reason = makeLabel(model.reasonText, font: ThawFont.body(14), color: Theme.inkSecondary)
        reason.numberOfLines = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? 0 : 1
        reason.lineBreakMode = .byTruncatingTail

        let summary = UIStackView(arrangedSubviews: [heading, reason])
        summary.axis = .vertical
        summary.spacing = 3
        summary.isAccessibilityElement = true
        summary.accessibilityLabel = model.spokenSummary

        let control = ReviewChoiceControl(choice: model.choice, labels: model.choiceLabels)
        control.onChange = { [weak self] choice in self?.presenter?.setChoice(id: model.id, choice: choice) }

        let column = UIStackView(arrangedSubviews: [summary, control])
        column.axis = .vertical
        column.spacing = 12
        column.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            column.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            column.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            column.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])
        return card
    }

    func update(_ summary: PaydayReviewSummary, animated: Bool) {
        meterCard?.update(fraction: summary.fraction, isOver: summary.isOver,
                          statusText: summary.statusText, animated: animated)
        cta.configuration?.title = summary.ctaTitle
    }

    func playSuccessFeedback() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func showDiscardConfirmation() {
        let sheet = UIAlertController(title: "Discard choices?", message: "Your picks won't be applied.",
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
