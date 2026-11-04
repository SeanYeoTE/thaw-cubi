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
        let heading = makeLabel("Saved since you started", font: ThawFont.body(15), color: Theme.inkSecondary)
        let amount = makeLabel(model.savedText, font: ThawFont.display(40))
        stack.addArrangedSubview(heading)
        stack.addArrangedSubview(amount)

        let countCard = CardView()
        let skippedLabel = makeLabel("Skipped", font: ThawFont.body(15), color: Theme.inkSecondary)
        let countValue = makeLabel(model.skippedText, font: ThawFont.display(22))
        let countStack = UIStackView(arrangedSubviews: [skippedLabel, countValue])
        countStack.axis = .vertical
        countStack.spacing = 4
        countStack.translatesAutoresizingMaskIntoConstraints = false
        countCard.addSubview(countStack)
        NSLayoutConstraint.activate([
            countStack.leadingAnchor.constraint(equalTo: countCard.leadingAnchor, constant: 16),
            countStack.trailingAnchor.constraint(equalTo: countCard.trailingAnchor, constant: -16),
            countStack.topAnchor.constraint(equalTo: countCard.topAnchor, constant: 16),
            countStack.bottomAnchor.constraint(equalTo: countCard.bottomAnchor, constant: -16),
        ])
        stack.addArrangedSubview(countCard)

        stack.addArrangedSubview(makeLabel("Payday pattern", font: ThawFont.body(13, weight: .medium), color: Theme.inkSecondary))
        stack.addArrangedSubview(makeLabel(model.pattern, font: ThawFont.body(16)))

        guard !model.history.isEmpty else { return }
        stack.addArrangedSubview(makeLabel("History", font: ThawFont.body(13, weight: .medium), color: Theme.inkSecondary))
        for row in model.history {
            stack.addArrangedSubview(historyRow(row))
        }
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
