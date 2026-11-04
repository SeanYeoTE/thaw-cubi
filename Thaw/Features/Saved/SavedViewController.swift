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
        let add = UIBarButtonItem(image: UIImage(systemName: "plus"), primaryAction: UIAction { [weak self] _ in
            self?.presenter?.tapAddGoal()
        })
        add.accessibilityLabel = "Add a goal"
        navigationItem.rightBarButtonItem = add
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        presenter?.viewWillAppear()
    }

    func render(_ model: SavedViewModel) {
        clearContent()
        let heading = makeLabel("Kept since you started", font: ThawFont.body(15), color: Theme.inkSecondary)
        let amount = makeLabel(model.keptText, font: ThawFont.display(40))
        stack.addArrangedSubview(heading)
        stack.addArrangedSubview(amount)

        if let pool = model.pool {
            let poolView = PendingPoolView()
            poolView.configure(amountText: pool.amountText, detail: pool.detail)
            stack.addArrangedSubview(poolView)
        }
        for row in model.goals {
            stack.addArrangedSubview(goalCard(row))
        }
        if let title = model.finishedTitle {
            var config = UIButton.Configuration.plain()
            config.title = title
            config.image = UIImage(systemName: model.finishedExpanded ? "chevron.up" : "chevron.down")
            config.imagePlacement = .trailing
            config.imagePadding = 8
            config.baseForegroundColor = Theme.inkSecondary
            let header = UIButton(configuration: config)
            header.contentHorizontalAlignment = .leading
            header.accessibilityTraits.insert(.header)
            header.accessibilityValue = model.finishedExpanded ? "Expanded" : "Collapsed"
            header.addAction(UIAction { [weak self] _ in self?.presenter?.tapFinishedHeader() }, for: .touchUpInside)
            stack.addArrangedSubview(header)
            for row in model.finished {
                stack.addArrangedSubview(goalCard(row))
            }
        }
        if model.showsInvite {
            stack.addArrangedSubview(inviteCard())
        }

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

        for line in model.skippedLines {
            stack.addArrangedSubview(makeLabel(line, font: ThawFont.body(15)))
        }
    }

    private func goalCard(_ row: SavedGoalRowViewModel) -> UIView {
        let card = GoalCardView()
        card.configure(row.card)
        card.isUserInteractionEnabled = false
        let button = UIControl()
        button.translatesAutoresizingMaskIntoConstraints = false
        card.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: button.topAnchor),
            card.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            card.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: button.trailingAnchor),
        ])
        button.isAccessibilityElement = true
        button.accessibilityLabel = row.card.accessibilityLabel
        button.accessibilityTraits = .button
        button.accessibilityHint = "Opens goal details"
        button.addAction(UIAction { [weak self] _ in self?.presenter?.tapGoal(id: row.id) }, for: .touchUpInside)
        return button
    }

    private func inviteCard() -> UIView {
        let card = CardView()
        let header = CubiHeaderView(mood: .snoozing, line: "Saving for something bigger?",
                                    spoken: "Saving for something bigger? Goals are optional.")
        let body = makeLabel("A goal holds money for a want that costs more than a month of fun money. "
                             + "What you skip, plus fun money you don't spend, tops it up at month end.",
                             font: ThawFont.body(15), color: Theme.inkSecondary)
        let add = PillButton(title: "Add a goal", style: .primary)
        add.addAction(UIAction { [weak self] _ in self?.presenter?.tapAddGoal() }, for: .touchUpInside)
        let notNow = PillButton(title: "Not now", style: .quiet)
        notNow.addAction(UIAction { [weak self] _ in self?.presenter?.tapNotNow() }, for: .touchUpInside)
        let inner = UIStackView(arrangedSubviews: [header, body, add, notNow])
        inner.axis = .vertical
        inner.spacing = 12
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            inner.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])
        return card
    }
}
