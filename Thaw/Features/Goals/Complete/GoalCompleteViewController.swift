import UIKit

final class GoalCompleteViewController: ScrollStackViewController, GoalCompleteViewProtocol {
    var presenter: GoalCompletePresenterProtocol?

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func buildContent() {
        stack.spacing = 16
        stack.alignment = .fill
        presenter?.viewDidLoad()
    }

    func render(_ model: GoalCompleteViewModel) {
        clearContent()
        title = model.title
        let cubi = CubiView(mood: .proud, size: 120)
        cubi.setContentHuggingPriority(.required, for: .vertical)
        let cubiRow = UIStackView(arrangedSubviews: [cubi])
        cubiRow.alignment = .center
        cubiRow.axis = .vertical
        stack.addArrangedSubview(cubiRow)

        let headline = makeLabel(model.headline, font: ThawFont.display(30))
        headline.textAlignment = .center
        stack.addArrangedSubview(headline)
        let amount = makeLabel(model.amountText, font: ThawFont.body(18, weight: .semibold), color: Theme.accent)
        amount.textAlignment = .center
        stack.addArrangedSubview(amount)
        let body = makeLabel(model.body, font: ThawFont.body(16), color: Theme.inkSecondary)
        body.textAlignment = .center
        stack.addArrangedSubview(body)

        let archive = PillButton(title: "Archive goal", style: .primary)
        archive.addAction(UIAction { [weak self] _ in self?.presenter?.tapArchive() }, for: .touchUpInside)
        stack.addArrangedSubview(archive)
        let later = PillButton(title: "Later", style: .quiet)
        later.addAction(UIAction { [weak self] _ in self?.presenter?.tapLater() }, for: .touchUpInside)
        stack.addArrangedSubview(later)
        let footnote = makeLabel(model.footnote, font: ThawFont.body(13), color: Theme.inkSecondary)
        footnote.textAlignment = .center
        stack.addArrangedSubview(footnote)
    }

    func playSuccessFeedback() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
