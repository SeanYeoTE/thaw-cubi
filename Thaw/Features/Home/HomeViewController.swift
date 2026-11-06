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
            let edit = UIAction(title: "Edit", image: UIImage(systemName: "pencil")) { [weak self] _ in
                self?.presenter?.tapEdit(id: item.id)
            }
            let delete = UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                self?.presenter?.tapDelete(id: item.id)
            }
            card.contextMenu = UIMenu(children: [edit, delete])
            card.accessibilityCustomActions = [
                UIAccessibilityCustomAction(name: "Edit") { [weak self] _ in
                    self?.presenter?.tapEdit(id: item.id)
                    return true
                },
                UIAccessibilityCustomAction(name: "Delete") { [weak self] _ in
                    self?.presenter?.tapDelete(id: item.id)
                    return true
                },
            ]
            stack.addArrangedSubview(card)
        }
    }

    func showDeleteConfirmation(id: UUID, confirmation: HomeDeleteConfirmation) {
        guard presentedViewController == nil else { return }
        let alert = UIAlertController(title: confirmation.title, message: confirmation.message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: confirmation.cancelTitle, style: .cancel))
        alert.addAction(UIAlertAction(title: confirmation.deleteTitle, style: .destructive) { [weak self] _ in
            self?.presenter?.confirmDelete(id: id)
        })
        present(alert, animated: true)
    }

    @objc private func addTapped() {
        presenter?.tapAdd()
    }

    @objc private func paydayTapped() {
        presenter?.tapPayday()
    }
}
