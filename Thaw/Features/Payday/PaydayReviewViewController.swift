import UIKit

/// Payday review: pick which thawed wants fit the fun money, Keep or Wait on each.
final class PaydayReviewViewController: ScrollStackViewController {
    private let store: WantStore
    private let reminders: Reminders
    private let wants: [Want]
    private var keeping: Set<UUID>

    private let amountLabel = UILabel()
    private let statusLabel = UILabel()
    private let meter = FunMoneyMeterView(fraction: 0, isOver: false)
    private let cta = PillButton(title: "Wait on all", style: .primary)

    private var budget: Decimal { store.effectiveSettings.funMoney }

    init(store: WantStore, reminders: Reminders, wants: [Want]) {
        self.store = store
        self.reminders = reminders
        self.wants = wants
        let budget = store.effectiveSettings.funMoney
        if let first = wants.first, first.price <= budget {
            keeping = [first.id]
        } else {
            keeping = []
        }
        super.init(nibName: nil, bundle: nil)
        title = "Payday review"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func buildContent() {
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeTapped))
        stack.spacing = 16

        stack.addArrangedSubview(CubiHeaderView(mood: .thawed, line: "Cubi: \u{201C}Pick what fits your fun money.\u{201D}",
                                              spoken: "Pick what fits your fun money."))
        stack.addArrangedSubview(makeMeterCard())

        for want in wants {
            stack.addArrangedSubview(makeRow(for: want))
        }

        stack.addArrangedSubview(makeLabel(
            "Anything you don't keep waits one more payday. Let go of it anytime from its page.",
            font: ThawFont.body(13), color: Theme.inkSecondary))

        cta.addAction(UIAction { [weak self] _ in self?.commit() }, for: .touchUpInside)
        stack.addArrangedSubview(cta)
        refresh(animated: false)
    }

    private func makeMeterCard() -> UIView {
        let card = UIView()
        card.backgroundColor = Theme.paydayCard
        card.layer.cornerRadius = 20

        let caption = makeLabel("Fun money this payday", font: ThawFont.body(14), color: Theme.paydayLabel)
        amountLabel.text = Formatting.sgd(budget)
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

    private func makeRow(for want: Want) -> UIView {
        let card = CardView()
        let name = makeLabel(want.name, font: ThawFont.body(16, weight: .semibold))
        let reason = makeLabel(want.reason.isEmpty ? "No reason written." : "\u{201C}\(want.reason)\u{201D}",
                               font: ThawFont.body(13), color: Theme.inkSecondary)
        reason.numberOfLines = 0
        let price = makeLabel(Formatting.sgd(want.price), font: ThawFont.money(16))
        price.setContentHuggingPriority(.required, for: .horizontal)
        price.setContentCompressionResistancePriority(.required, for: .horizontal)

        let toggle = KeepToggleButton(isKeeping: keeping.contains(want.id))
        toggle.name = want.name
        toggle.addAction(UIAction { [weak self, weak toggle] _ in
            guard let self, let toggle else { return }
            if toggle.isKeeping { self.keeping.insert(want.id) } else { self.keeping.remove(want.id) }
            self.refresh(animated: true)
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

    private var keptWants: [Want] { wants.filter { keeping.contains($0.id) } }

    private func refresh(animated: Bool) {
        let kept = keptWants
        let summary = FunMoneySummary.make(keptPrices: kept.map(\.price), budget: budget)
        let isOver = summary.overBy > 0
        meter.update(fraction: summary.fraction, isOver: isOver, animated: animated)
        statusLabel.textColor = isOver ? Theme.paydaySubtext : Theme.cubeFill
        statusLabel.text = isOver
            ? "\(Formatting.sgd(summary.kept)) kept · \(Formatting.sgd(summary.overBy)) over your fun money"
            : "\(Formatting.sgd(summary.kept)) kept · \(Formatting.sgd(summary.remaining)) left"
        cta.configuration?.title = kept.isEmpty ? "Wait on all" : "Keep \(kept.count) · \(Formatting.sgd(summary.kept))"
    }

    private func commit() {
        for want in wants {
            store.decide(id: want.id, keep: keeping.contains(want.id))
        }
        reminders.refresh(requestingPermission: false)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        view.window?.rootViewController?.dismiss(animated: true)
    }

    @objc private func closeTapped() {
        view.window?.rootViewController?.dismiss(animated: true)
    }
}
