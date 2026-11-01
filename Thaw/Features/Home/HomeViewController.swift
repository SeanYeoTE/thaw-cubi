import UIKit

final class HomeViewController: ScrollStackViewController, HomeViewProtocol {
    var presenter: HomePresenterProtocol?

    init() {
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
        presenter?.viewWillAppear()
    }

    func render(_ model: HomeViewModel) {
        clearContent()
        let payday = PaydayCardView(daysLeft: model.daysLeft, nextPayday: model.nextPaydayText,
                                    subtitle: model.paydaySubtitle)
        payday.addTarget(self, action: #selector(paydayTapped), for: .touchUpInside)
        payday.isEnabled = model.hasReview
        payday.alpha = model.hasReview ? 1 : 0.5
        payday.accessibilityHint = model.hasReview ? "Opens the payday preview" : "Nothing has thawed yet"
        stack.addArrangedSubview(payday)

        if let empty = model.emptyText {
            stack.addArrangedSubview(makeLabel(empty, font: ThawFont.body(15), color: Theme.inkSecondary))
        }
        for item in model.cards {
            let card = WantCardView(model: item)
            card.addAction(UIAction { [weak self] _ in self?.presenter?.tapWant(id: item.id) }, for: .touchUpInside)
            stack.addArrangedSubview(card)
        }
    }

    @objc private func addTapped() {
        presenter?.tapAdd()
    }

    @objc private func paydayTapped() {
        presenter?.tapPayday()
    }
}
