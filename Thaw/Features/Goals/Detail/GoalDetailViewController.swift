import UIKit

final class GoalDetailViewController: ScrollStackViewController, GoalDetailViewProtocol {
    var presenter: GoalDetailPresenterProtocol?
    private var editButton: UIBarButtonItem?

    init() {
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func buildContent() {
        navigationItem.largeTitleDisplayMode = .never
        stack.spacing = 18
        presenter?.viewDidLoad()
    }

    func render(_ model: GoalDetailViewModel) {
        clearContent()
        title = model.name
        let edit = UIBarButtonItem(title: "Edit", primaryAction: UIAction { [weak self] _ in self?.presenter?.tapEdit() })
        navigationItem.rightBarButtonItem = model.canEdit ? edit : nil

        stack.addArrangedSubview(makeLabel(model.name, font: ThawFont.display(34)))
        if model.fillsFirst || model.extended {
            let tags = AdaptiveStackView()
            tags.spacing = 8
            tags.compactAlignment = .leading
            if model.fillsFirst { tags.addArrangedSubview(TagLabel(text: "Fills first", style: .fillsFirst)) }
            if model.extended { tags.addArrangedSubview(TagLabel(text: "Extended", style: .extended)) }
            tags.addArrangedSubview(UIView())
            stack.addArrangedSubview(tags)
        }
        stack.addArrangedSubview(makeHeader(model))

        if !model.contributions.isEmpty {
            stack.addArrangedSubview(makeSection("Contributions", rows: model.contributions.map { row in
                makeRow(title: row.month, detail: nil, value: row.amount, valueColor: Theme.accent)
            }))
        }
        stack.addArrangedSubview(makeSection("History", rows: model.history.map { row in
            makeRow(title: row.title, detail: row.detail, value: row.date, valueColor: Theme.inkSecondary)
        }))

        if model.canArchive {
            let archive = PillButton(title: "Archive goal", style: .secondary)
            archive.addAction(UIAction { [weak self] _ in self?.presenter?.tapArchive() }, for: .touchUpInside)
            stack.addArrangedSubview(archive)
        }
        let delete = PillButton(title: "Delete goal", style: .quiet)
        delete.configuration?.baseForegroundColor = Theme.destructive
        delete.addAction(UIAction { [weak self] _ in self?.presenter?.tapDelete() }, for: .touchUpInside)
        stack.addArrangedSubview(delete)
        stack.addArrangedSubview(makeLabel(model.deleteNote, font: ThawFont.body(13), color: Theme.inkSecondary))
    }

    func showDeleteConfirmation(title: String, message: String) {
        guard presentedViewController == nil else { return }
        let sheet = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Delete goal", style: .destructive) { [weak self] _ in
            self?.presenter?.confirmDelete()
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = view
        sheet.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        present(sheet, animated: true)
    }

    private func makeHeader(_ model: GoalDetailViewModel) -> UIView {
        let card = UIView()
        card.backgroundColor = Theme.paydayCard
        card.layer.cornerRadius = Theme.Radius.card
        let caption = makeLabel("Saved so far", font: ThawFont.body(13, weight: .medium), color: Theme.paydayLabel)
        let amount = makeLabel(model.savedText, font: ThawFont.display(40), color: .white)
        let meter = FunMoneyMeterView(fraction: model.progress, isOver: false)
        let of = makeLabel(model.progressText, font: ThawFont.body(14), color: Theme.paydayLabel)
        var parts: [UIView] = [caption, amount, meter, of]
        if let due = model.dueText {
            parts.append(makeLabel(due, font: ThawFont.body(14), color: Theme.paydaySubtext))
        }
        let inner = UIStackView(arrangedSubviews: parts)
        inner.axis = .vertical
        inner.spacing = 8
        pin(inner, in: card, inset: 18)
        card.isAccessibilityElement = true
        card.accessibilityLabel = model.accessibilityLabel
        return card
    }

    private func makeSection(_ heading: String, rows: [UIView]) -> UIView {
        let card = CardView()
        let content = UIStackView(arrangedSubviews: [makeLabel(heading, font: ThawFont.body(13, weight: .medium), color: Theme.inkSecondary)] + rows)
        content.axis = .vertical
        content.spacing = 12
        pin(content, in: card, inset: 18)
        return card
    }

    private func makeRow(title: String, detail: String?, value: String, valueColor: UIColor) -> UIView {
        let titleLabel = makeLabel(title, font: ThawFont.body(16))
        let text = UIStackView(arrangedSubviews: [titleLabel])
        text.axis = .vertical
        text.spacing = 2
        if let detail { text.addArrangedSubview(makeLabel(detail, font: ThawFont.body(13), color: Theme.inkSecondary)) }
        let valueLabel = makeLabel(value, font: ThawFont.body(16, weight: .semibold), color: valueColor)
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        let row = AdaptiveStackView(arrangedSubviews: [text, valueLabel])
        row.spacing = 12
        row.compactAlignment = .firstBaseline
        row.isAccessibilityElement = false
        return row
    }

    private func pin(_ inner: UIView, in card: UIView, inset: CGFloat) {
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: inset),
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -inset),
            inner.topAnchor.constraint(equalTo: card.topAnchor, constant: inset),
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -inset),
        ])
    }
}
