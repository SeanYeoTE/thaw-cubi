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
        if let notice = model.notice {
            stack.addArrangedSubview(noticeCard(notice))
        }
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

    private func noticeCard(_ notice: HomeNoticeViewModel) -> UIView {
        let container = UIView()
        let card = CardView()
        card.backgroundColor = Theme.frost
        card.layer.borderColor = Theme.frostBorder.cgColor
        card.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(card)

        let title = makeLabel(notice.title, font: ThawFont.body(16, weight: .bold))
        title.numberOfLines = 0
        let lines = notice.lines.map { makeLabel($0, font: ThawFont.body(14), color: Theme.toggleText) }
        lines.forEach { $0.numberOfLines = 0 }
        let hint = makeLabel(notice.completesGoal ? "Tap to see your goal" : "Tap to open Saved",
                             font: ThawFont.body(13, weight: .semibold), color: Theme.frostText)
        let text = UIStackView(arrangedSubviews: [title] + lines + [hint])
        text.axis = .vertical
        text.spacing = 4
        text.setCustomSpacing(8, after: lines.last ?? title)
        text.isUserInteractionEnabled = false
        text.translatesAutoresizingMaskIntoConstraints = false

        let tap = UIControl()
        tap.translatesAutoresizingMaskIntoConstraints = false
        tap.isAccessibilityElement = true
        tap.accessibilityLabel = ([notice.title] + notice.lines).joined(separator: ". ")
        tap.accessibilityTraits = .button
        tap.addAction(UIAction { [weak self] _ in self?.presenter?.tapNotice() }, for: .touchUpInside)

        var closeConfig = UIButton.Configuration.plain()
        closeConfig.image = UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .bold))
        closeConfig.baseForegroundColor = Theme.frostText
        closeConfig.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        let close = UIButton(configuration: closeConfig)
        close.accessibilityLabel = "Dismiss month-end summary"
        close.translatesAutoresizingMaskIntoConstraints = false
        close.addAction(UIAction { [weak self] _ in self?.presenter?.dismissNotice() }, for: .touchUpInside)

        card.addSubview(tap)
        card.addSubview(text)
        card.addSubview(close)
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            card.topAnchor.constraint(equalTo: container.topAnchor),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            tap.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            tap.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            tap.topAnchor.constraint(equalTo: card.topAnchor),
            tap.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            text.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            text.trailingAnchor.constraint(equalTo: close.leadingAnchor, constant: -4),
            text.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            text.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            close.topAnchor.constraint(equalTo: card.topAnchor, constant: 6),
            close.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -6),
            close.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            close.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
        ])
        return container
    }
}
