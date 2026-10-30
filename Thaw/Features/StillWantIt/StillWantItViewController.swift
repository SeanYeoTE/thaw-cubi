import UIKit

final class StillWantItViewController: UIViewController {
    private let store: WantStore
    private var queue: [Want]
    private var index = 0
    private var boughtTotal: Decimal = 0
    private let total: Int

    private let progressLabel = UILabel()
    private let question = UILabel()
    private let price = UILabel()
    private let quote = UILabel()
    private let funLabel = UILabel()
    private let keep = PillButton(title: "", style: .secondary)
    private let buy = PillButton(title: "Yes, I'll buy it", style: .primary)
    private let unsure = PillButton(title: "Not sure? Wait one more payday", style: .quiet)

    init(store: WantStore, queue: [Want]) {
        self.store = store
        self.queue = queue
        self.total = queue.count
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeTapped))

        progressLabel.font = ThawFont.body(13, weight: .medium)
        progressLabel.textColor = Theme.inkSecondary
        question.font = ThawFont.display(28)
        question.textColor = Theme.ink
        question.numberOfLines = 0
        price.font = ThawFont.money(20)
        price.textColor = Theme.ink
        quote.font = ThawFont.body(16)
        quote.textColor = Theme.inkSecondary
        quote.numberOfLines = 0
        funLabel.font = ThawFont.body(15)
        funLabel.textColor = Theme.inkSecondary
        funLabel.numberOfLines = 0

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

        keep.addAction(UIAction { [weak self] _ in self?.decide(.skipped) }, for: .touchUpInside)
        buy.addAction(UIAction { [weak self] _ in self?.decide(.bought) }, for: .touchUpInside)
        unsure.addAction(UIAction { [weak self] _ in self?.decideWait() }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [card, funLabel, keep, buy, unsure])
        stack.axis = .vertical
        stack.spacing = 14
        stack.setCustomSpacing(18, after: funLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Theme.Spacing.screen),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Theme.Spacing.screen),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
        ])
        render()
    }

    private var current: Want { queue[index] }

    private func render() {
        let want = current
        progressLabel.text = "Payday review · \(index + 1) of \(total)"
        question.text = "Still want the \(want.name.lowercased())?"
        price.text = Formatting.sgd(want.price)
        quote.text = "On \(Formatting.paydayDate(want.frozenOn)), you said\n\u{201C}\(want.reason.isEmpty ? "No reason written." : want.reason)\u{201D}"
        let left = store.payday.funMoney - boughtTotal
        let ifBuy = left - want.price
        funLabel.text = "Fun money if you buy: \(Formatting.sgd(ifBuy)) of \(Formatting.sgd(store.payday.funMoney)) left"
        keep.configuration?.title = "Skip and keep \(Formatting.sgd(want.price))"
    }

    private func decide(_ status: Want.Status) {
        store.update(current.id, status: status)
        if status == .bought { boughtTotal += current.price }
        advance()
    }

    private func decideWait() {
        store.decide(id: current.id, keep: false)
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
