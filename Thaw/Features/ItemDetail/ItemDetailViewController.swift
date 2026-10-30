import UIKit

final class ItemDetailViewController: ScrollStackViewController {
    private let store: WantStore
    private let want: Want

    init(store: WantStore, want: Want) {
        self.store = store
        self.want = want
        super.init(nibName: nil, bundle: nil)
        title = "Item detail"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func buildContent() {
        navigationItem.largeTitleDisplayMode = .never
        stack.spacing = 18
        stack.addArrangedSubview(makeLabel(want.name, font: ThawFont.display(34)))
        stack.addArrangedSubview(makeLabel(
            "\(Formatting.sgd(want.price)) · frozen \(Formatting.paydayDate(want.frozenOn))",
            font: ThawFont.body(15), color: Theme.inkSecondary))

        let countdown = CardView()
        let days = UILabel()
        days.text = "\(store.payday.daysUntilNext) days"
        days.font = ThawFont.display(36)
        days.textColor = Theme.ink
        let until = makeLabel("until payday · \(Formatting.paydayDate(store.payday.nextPayday))",
                              font: ThawFont.body(14), color: Theme.inkSecondary)
        let progress = ProgressBarView(fraction: CGFloat(want.progress),
                                       color: want.isUnderTimerThreshold ? Theme.warm : Theme.accent)
        let countStack = UIStackView(arrangedSubviews: [days, until, progress])
        countStack.axis = .vertical
        countStack.spacing = 10
        pin(countStack, in: countdown, inset: 18)
        stack.addArrangedSubview(countdown)

        let reasonCard = CardView()
        let heading = makeLabel("Why you froze it", font: ThawFont.body(13, weight: .medium), color: Theme.inkSecondary)
        let quote = makeLabel("\u{201C}\(want.reason.isEmpty ? "No reason written." : want.reason)\u{201D}",
                              font: ThawFont.body(17))
        let reasonStack = UIStackView(arrangedSubviews: [heading, quote])
        reasonStack.axis = .vertical
        reasonStack.spacing = 8
        pin(reasonStack, in: reasonCard, inset: 18)
        stack.addArrangedSubview(reasonCard)

        let thaws = makeLabel(
            "Thaws · Payday · \(Formatting.paydayDate(store.payday.nextPayday)) · 9:00 am",
            font: ThawFont.body(14), color: Theme.inkSecondary)
        stack.addArrangedSubview(thaws)

        let wait = PillButton(title: "Wait one more payday", style: .secondary)
        wait.addAction(UIAction { [weak self] _ in self?.waitOnePayday() }, for: .touchUpInside)
        stack.addArrangedSubview(wait)

        let decide = PillButton(title: "Decide now", style: .quiet)
        decide.addAction(UIAction { [weak self] _ in self?.decideNow() }, for: .touchUpInside)
        stack.addArrangedSubview(decide)

        let skip = PillButton(title: "Skip it now", style: .quiet)
        skip.addAction(UIAction { [weak self] _ in self?.skip() }, for: .touchUpInside)
        stack.addArrangedSubview(skip)
    }

    private func decideNow() {
        let controller = StillWantItViewController(store: store, queue: [want])
        let nav = UINavigationController(rootViewController: controller)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    private func waitOnePayday() {
        store.decide(id: want.id, keep: false)
        navigationController?.popViewController(animated: true)
    }

    private func skip() {
        store.update(want.id, status: .skipped)
        navigationController?.popViewController(animated: true)
    }

    private func pin(_ inner: UIView, in card: CardView, inset: CGFloat) {
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
