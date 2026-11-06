import UIKit

final class ItemDetailViewController: ScrollStackViewController, ItemDetailViewProtocol {
    var presenter: ItemDetailPresenterProtocol?

    init() {
        super.init(nibName: nil, bundle: nil)
        title = "Item detail"
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func buildContent() {
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Edit", primaryAction: UIAction { [weak self] _ in
            self?.presenter?.tapEdit()
        })
        stack.spacing = 18
        presenter?.viewDidLoad()
    }

    func render(_ model: ItemDetailViewModel) {
        clearContent()
        stack.addArrangedSubview(makeLabel(model.name, font: ThawFont.display(34)))
        stack.addArrangedSubview(makeLabel(model.subtitle, font: ThawFont.body(15), color: Theme.inkSecondary))

        let countdown = CardView()
        let days = makeLabel(model.daysText, font: ThawFont.display(36))
        let until = makeLabel(model.untilText, font: ThawFont.body(14), color: Theme.inkSecondary)
        let progress = ProgressBarView(fraction: CGFloat(model.progress), color: model.isTimer ? Theme.warm : Theme.accent)
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

        stack.addArrangedSubview(makeLabel(model.thawsText, font: ThawFont.body(14), color: Theme.inkSecondary))

        let wait = PillButton(title: "Wait one more payday", style: .secondary)
        wait.addAction(UIAction { [weak self] _ in self?.presenter?.tapWait() }, for: .touchUpInside)
        stack.addArrangedSubview(wait)

        let decide = PillButton(title: "Decide now", style: .quiet)
        decide.addAction(UIAction { [weak self] _ in self?.presenter?.tapDecide() }, for: .touchUpInside)
        stack.addArrangedSubview(decide)

        let skip = PillButton(title: "Skip it now", style: .quiet)
        skip.addAction(UIAction { [weak self] _ in self?.presenter?.tapSkip() }, for: .touchUpInside)
        stack.addArrangedSubview(skip)
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
