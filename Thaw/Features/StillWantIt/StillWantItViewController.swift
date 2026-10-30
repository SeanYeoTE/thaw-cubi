import UIKit

/// One-want-at-a-time decision, reached from Item detail.
final class StillWantItViewController: ScrollStackViewController {
    private let store: WantStore
    private let reminders: Reminders
    private let queue: [Want]
    private var index = 0
    private var boughtTotal: Decimal = 0

    private let progressLabel = UILabel()
    private let question = UILabel()
    private let price = UILabel()
    private let quote = UILabel()
    private let funLabel = UILabel()
    private let keep = PillButton(title: "", style: .secondary)
    private let buy = PillButton(title: "Yes, I'll buy it", style: .primary)
    private let unsure = PillButton(title: "Not sure? Wait one more payday", style: .quiet)

    init(store: WantStore, reminders: Reminders, queue: [Want]) {
        self.store = store
        self.reminders = reminders
        self.queue = queue
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

        keep.addAction(UIAction { [weak self] _ in self?.skip() }, for: .touchUpInside)
        buy.addAction(UIAction { [weak self] _ in self?.decideBuy() }, for: .touchUpInside)
        unsure.addAction(UIAction { [weak self] _ in self?.decideWait() }, for: .touchUpInside)

        [card, funLabel, keep, buy, unsure].forEach(stack.addArrangedSubview)
        stack.setCustomSpacing(18, after: funLabel)
        render()
    }

    private var current: Want { queue[index] }

    private func render() {
        let want = current
        progressLabel.text = "Payday review · \(index + 1) of \(queue.count)"
        question.text = "Still want the \(want.name.lowercased())?"
        price.text = Formatting.sgd(want.price)
        quote.text = "On \(Formatting.paydayDate(want.frozenOn)), you said\n\u{201C}\(want.reason.isEmpty ? "No reason written." : want.reason)\u{201D}"
        let budget = store.effectiveSettings.funMoney
        let ifBuy = budget - boughtTotal - want.price
        funLabel.text = "Fun money if you buy: \(Formatting.sgd(ifBuy)) of \(Formatting.sgd(budget)) left"
        keep.configuration?.title = "Skip and keep \(Formatting.sgd(want.price))"
    }

    private func skip() {
        let want = current
        store.update(want.id, status: .skipped)
        reminders.refresh(requestingPermission: false)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        navigationController?.setNavigationBarHidden(true, animated: true)
        MomentView.present(on: view, mood: .proud, line: CubiMood.proudLine(amount: Formatting.sgd(want.price))) { [weak self] in
            self?.navigationController?.setNavigationBarHidden(false, animated: false)
            self?.advance()
        }
    }

    private func decideBuy() {
        let want = current
        store.decide(id: want.id, keep: true)
        boughtTotal += want.price
        reminders.refresh(requestingPermission: false)
        advance()
    }

    private func decideWait() {
        store.decide(id: current.id, keep: false)
        reminders.refresh(requestingPermission: false)
        advance()
    }

    private func advance() {
        index += 1
        if index >= queue.count {
            view.window?.rootViewController?.dismiss(animated: true)
        } else {
            render()
        }
    }

    @objc private func closeTapped() {
        view.window?.rootViewController?.dismiss(animated: true)
    }
}
