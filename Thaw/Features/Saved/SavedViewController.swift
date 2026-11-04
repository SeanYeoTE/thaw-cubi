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
        let heading = makeLabel("Kept since you started", font: ThawFont.body(15), color: Theme.inkSecondary)
        let amount = makeLabel(model.keptText, font: ThawFont.display(40))
        stack.addArrangedSubview(heading)
        stack.addArrangedSubview(amount)

        let goalCard = CardView()
        let goalText = makeLabel(model.goalTitle, font: ThawFont.body(15, weight: .semibold))
        let progress = ProgressBarView(fraction: CGFloat(model.goalFraction), color: Theme.accent)
        let goalCaption = makeLabel(model.goalCaption, font: ThawFont.body(13), color: Theme.inkSecondary)
        let goalStack = UIStackView(arrangedSubviews: [goalText, progress, goalCaption])
        goalStack.axis = .vertical
        goalStack.spacing = 10
        goalStack.translatesAutoresizingMaskIntoConstraints = false
        goalCard.addSubview(goalStack)
        NSLayoutConstraint.activate([
            goalStack.leadingAnchor.constraint(equalTo: goalCard.leadingAnchor, constant: 16),
            goalStack.trailingAnchor.constraint(equalTo: goalCard.trailingAnchor, constant: -16),
            goalStack.topAnchor.constraint(equalTo: goalCard.topAnchor, constant: 16),
            goalStack.bottomAnchor.constraint(equalTo: goalCard.bottomAnchor, constant: -16),
        ])
        stack.addArrangedSubview(goalCard)

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
}
