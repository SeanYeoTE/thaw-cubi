import UIKit

final class SavedViewController: ScrollStackViewController, SavedViewProtocol {
    var presenter: SavedPresenterProtocol?

    init() {
        super.init(nibName: nil, bundle: nil)
        title = "Saved"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func buildContent() {
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always
        stack.spacing = 14
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        presenter?.viewWillAppear()
    }

    func render(_ model: SavedViewModel) {
        clearContent()
        stack.addArrangedSubview(CubiHeaderView(mood: model.cubi.mood, line: model.cubi.line, spoken: model.cubi.line))
        let heading = makeLabel("Saved since you started", font: ThawFont.body(15), color: Theme.inkSecondary)
        let amount = makeLabel(model.savedText, font: ThawFont.display(40))
        stack.addArrangedSubview(heading)
        stack.addArrangedSubview(amount)

        if let progress = model.progress {
            stack.addArrangedSubview(makeLabel("Your progress", font: ThawFont.body(13, weight: .medium), color: Theme.inkSecondary))
            stack.addArrangedSubview(progressCard(progress))
        } else if let emptyText = model.emptyText {
            stack.addArrangedSubview(makeLabel(emptyText, font: ThawFont.body(16)))
        }

        guard !model.history.isEmpty else { return }
        stack.addArrangedSubview(makeLabel("History", font: ThawFont.body(13, weight: .medium), color: Theme.inkSecondary))
        for row in model.history {
            stack.addArrangedSubview(historyRow(row))
        }
    }

    private func progressCard(_ model: SavedProgressViewModel) -> UIView {
        let card = CardView()
        let column = UIStackView()
        column.axis = .vertical
        column.spacing = 14
        for stat in model.stats {
            let value = makeLabel(stat.value, font: ThawFont.display(20))
            let caption = makeLabel(stat.caption, font: ThawFont.body(13), color: Theme.inkSecondary)
            let item = UIStackView(arrangedSubviews: [value, caption])
            item.axis = .vertical
            item.spacing = 2
            item.isAccessibilityElement = true
            item.accessibilityLabel = "\(stat.value). \(stat.caption)"
            column.addArrangedSubview(item)
        }
        column.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            column.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            column.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            column.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])
        return card
    }

    private func historyRow(_ row: SavedHistoryRow) -> UIView {
        let card = CardView()
        let name = makeLabel(row.name, font: ThawFont.body(16, weight: .semibold))
        let detail = makeLabel("\(row.outcome) · \(row.dateText)", font: ThawFont.body(13),
                               color: row.isSkipped ? Theme.accent : Theme.inkSecondary)
        let price = makeLabel(row.priceText, font: ThawFont.money(16))
        price.setContentHuggingPriority(.required, for: .horizontal)
        let texts = UIStackView(arrangedSubviews: [name, detail])
        texts.axis = .vertical
        texts.spacing = 2
        let line = UIStackView(arrangedSubviews: [texts, price])
        line.axis = .horizontal
        line.alignment = .center
        line.spacing = 12
        line.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(line)
        NSLayoutConstraint.activate([
            line.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            line.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            line.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            line.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])
        return card
    }
}
