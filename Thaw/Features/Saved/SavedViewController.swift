import UIKit

final class SavedViewController: ScrollStackViewController {
    private let store: WantStore

    init(store: WantStore) {
        self.store = store
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
        render()
    }

    private func render() {
        clearContent()
        let skipped = store.wants.filter { $0.status == .skipped }
        let decided = store.wants.filter { $0.status != .cooling }
        let kept = skipped.reduce(Decimal(0)) { $0 + $1.price }
        let goal = Decimal(2000)

        let heading = makeLabel("Kept since you started", font: ThawFont.body(15), color: Theme.inkSecondary)
        let amount = makeLabel(Formatting.sgd(kept), font: ThawFont.display(40))
        stack.addArrangedSubview(heading)
        stack.addArrangedSubview(amount)

        let goalCard = CardView()
        let goalText = makeLabel("Goal: Japan trip", font: ThawFont.body(15, weight: .semibold))
        let progress = ProgressBarView(fraction: CGFloat(truncating: (kept / goal) as NSNumber), color: Theme.accent)
        let goalCaption = makeLabel("\(Formatting.sgd(kept)) of \(Formatting.sgd(goal))", font: ThawFont.body(13), color: Theme.inkSecondary)
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
        let countValue = makeLabel("\(skipped.count) of \(decided.count)", font: ThawFont.display(22))
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

        let pattern = decided.isEmpty
            ? "Decide on a few wants at payday and your pattern will show up here."
            : "By payday, you've let go of \(skipped.count) in \(decided.count) wants."
        stack.addArrangedSubview(makeLabel("Payday pattern", font: ThawFont.body(13, weight: .medium), color: Theme.inkSecondary))
        stack.addArrangedSubview(makeLabel(pattern, font: ThawFont.body(16)))

        for want in skipped {
            stack.addArrangedSubview(makeLabel("\(want.name) · \(Formatting.sgd(want.price))", font: ThawFont.body(15)))
        }
    }
}
