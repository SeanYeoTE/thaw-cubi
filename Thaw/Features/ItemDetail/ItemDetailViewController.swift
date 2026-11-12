import UIKit

final class ItemDetailViewController: ScrollStackViewController, ItemDetailViewProtocol {
    var presenter: ItemDetailPresenterProtocol?

    init() {
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func buildContent() {
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Edit", primaryAction: UIAction { [weak self] _ in
            self?.presenter?.tapEdit()
        })
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "detail.edit"
        stack.spacing = 18
        presenter?.viewDidLoad()
    }

    func render(_ model: ItemDetailViewModel) {
        clearContent()
        stack.addArrangedSubview(makeLabel(model.name, font: ThawFont.display(34)))
        stack.addArrangedSubview(makeLabel(model.priceText, font: ThawFont.money(28)))
        stack.addArrangedSubview(makeLabel(model.frozenText, font: ThawFont.body(15), color: Theme.inkSecondary))

        let countdown = CardView()
        let days = makeLabel(model.daysText, font: ThawFont.display(36))
        let until = makeLabel(model.captionText, font: ThawFont.body(14), color: Theme.inkSecondary)
        let progress = ProgressBarView(fraction: CGFloat(model.progress), color: model.isTimer ? Theme.timer : Theme.accent)
        let countStack = UIStackView(arrangedSubviews: [days, until, progress])
        countStack.axis = .vertical
        countStack.spacing = 10
        pin(countStack, in: countdown, inset: 18)
        stack.addArrangedSubview(countdown)

        let reasonCard = CardView()
        let heading = makeLabel("Why you froze it", font: ThawFont.body(13, weight: .medium), color: Theme.inkSecondary)
        let quote = makeLabel(model.quote, font: ThawFont.body(17))
        let reasonStack = UIStackView(arrangedSubviews: [heading, quote])
        reasonStack.axis = .vertical
        reasonStack.spacing = 8
        pin(reasonStack, in: reasonCard, inset: 18)
        stack.addArrangedSubview(reasonCard)

        if let linkText = model.linkText {
            stack.addArrangedSubview(linkRow(linkText))
        }

        let letGo = PillButton(title: model.letGoTitle, style: .primary)
        letGo.accessibilityIdentifier = "detail.letGo"
        letGo.addAction(UIAction { [weak self] _ in self?.presenter?.tapLetGo() }, for: .touchUpInside)
        stack.addArrangedSubview(letGo)

        let decide = PillButton(title: "Decide now", style: .secondary)
        decide.accessibilityIdentifier = "detail.decide"
        decide.addAction(UIAction { [weak self] _ in self?.presenter?.tapDecide() }, for: .touchUpInside)
        stack.addArrangedSubview(decide)
    }

    func showLetGoConfirmation(title: String, confirmTitle: String, cancelTitle: String, onConfirm: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel))
        alert.addAction(UIAlertAction(title: confirmTitle, style: .destructive) { _ in onConfirm() })
        present(alert, animated: true)
    }

    func showSkipMoment(line: String, completion: @escaping () -> Void) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        navigationController?.setNavigationBarHidden(true, animated: true)
        MomentView.present(on: view, mood: .proud, line: line) { [weak self] in
            self?.navigationController?.setNavigationBarHidden(false, animated: false)
            completion()
        }
    }

    private func linkRow(_ text: String) -> UIView {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "safari")
        config.imagePadding = 8
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0)
        config.baseForegroundColor = Theme.accent
        config.titleLineBreakMode = .byTruncatingMiddle
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = ThawFont.body(16, weight: .medium)
            return attributes
        }
        config.title = text
        let button = UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in
            self?.presenter?.tapLink()
        })
        button.contentHorizontalAlignment = .leading
        button.accessibilityIdentifier = "detail.link"
        button.accessibilityTraits = .link
        button.accessibilityHint = "Opens in Safari"
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        return button
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
