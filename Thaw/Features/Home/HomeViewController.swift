import UIKit

final class HomeViewController: ScrollStackViewController {
    private let store: WantStore
    private let summaryLabel = UILabel()

    init(store: WantStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
        title = "Cooling"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func buildContent() {
        navigationItem.largeTitleDisplayMode = .always
        let add = UIButton(type: .custom)
        add.setImage(UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)), for: .normal)
        add.tintColor = .white
        add.backgroundColor = Theme.accent
        add.layer.cornerRadius = 22
        add.accessibilityLabel = "Add a want"
        add.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        add.widthAnchor.constraint(equalToConstant: 44).isActive = true
        add.heightAnchor.constraint(equalToConstant: 44).isActive = true
        let addItem = UIBarButtonItem(customView: add)
        if #available(iOS 26.0, *) {
            addItem.hidesSharedBackground = true
        }
        navigationItem.rightBarButtonItem = addItem
        navigationController?.navigationBar.prefersLargeTitles = true
        view.backgroundColor = Theme.background
        stack.spacing = 18
        scrollView.contentInsetAdjustmentBehavior = .automatic
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        render()
    }

    private func render() {
        clearContent()
        let thawing = store.cooling.filter { !$0.isUnderTimerThreshold }
        let thawingTotal = thawing.reduce(Decimal(0)) { $0 + $1.price }
        let payday = PaydayCardView(
            daysLeft: store.payday.daysUntilNext,
            nextPayday: Formatting.paydayDate(store.payday.nextPayday),
            subtitle: "\(thawing.count) wants thaw then · \(Formatting.sgd(thawingTotal)) vs \(Formatting.sgd(store.payday.funMoney)) fun money"
        )
        payday.addTarget(self, action: #selector(paydayTapped), for: .touchUpInside)
        stack.addArrangedSubview(payday)

        let items = store.cooling.map { want -> UIView in
            let card = WantCardView(want: want)
            card.addAction(UIAction { [weak self] _ in self?.open(want.id) }, for: .touchUpInside)
            return card
        }
        if items.isEmpty {
            stack.addArrangedSubview(makeLabel("Nothing cooling. Add a want to start the wait.",
                                               font: ThawFont.body(15), color: Theme.inkSecondary))
        }
        items.forEach { stack.addArrangedSubview($0) }
    }

    private func open(_ id: UUID) {
        guard let want = store.want(id: id) else { return }
        navigationController?.pushViewController(ItemDetailViewController(store: store, want: want), animated: true)
    }

    @objc private func addTapped() {
        let controller = AddWantViewController(store: store) { [weak self] in self?.render() }
        present(UINavigationController(rootViewController: controller), animated: true)
    }

    @objc private func paydayTapped() {
        let controller = PaydayNotificationViewController(store: store)
        present(controller, animated: true)
    }
}
