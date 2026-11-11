import UIKit

/// Onboarding: the one-question payday flow, full page with the nav bar hidden.
final class PaydaySetupViewController: ScrollStackViewController, PaydaySetupViewProtocol {
    var presenter: PaydaySetupPresenterProtocol?

    private let choiceStack = UIStackView()
    private let detailHost = UIStackView()
    private let continueButton = PillButton(title: "Continue", style: .primary)

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func buildContent() {
        navigationItem.largeTitleDisplayMode = .never
        stack.spacing = 16
        presenter?.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    func render(_ content: PaydaySetupContent) {
        let heading = makeLabel(content.heading, font: ThawFont.display(34))
        heading.accessibilityTraits = .header
        let subtitle = makeLabel(content.subtitle, font: ThawFont.body(15), color: Theme.inkSecondary)
        let intro = UIStackView(arrangedSubviews: [heading, subtitle])
        intro.axis = .vertical
        intro.spacing = 6
        stack.addArrangedSubview(intro)

        let legend = makeLabel(content.legend, font: ThawFont.body(13, weight: .bold), color: Theme.inkSecondary)
        stack.addArrangedSubview(legend)
        stack.setCustomSpacing(8, after: legend)
        choiceStack.axis = .vertical
        choiceStack.spacing = 8
        stack.addArrangedSubview(choiceStack)
        renderChoices(content.choices)

        detailHost.axis = .vertical
        stack.addArrangedSubview(detailHost)
        renderDetail(content.detail)

        let notice = makeLabel(content.notice, font: ThawFont.body(13), color: Theme.inkSecondary)
        notice.textAlignment = .center
        stack.addArrangedSubview(notice)

        continueButton.addAction(UIAction { [weak self] _ in self?.presenter?.tapContinue() }, for: .touchUpInside)
        stack.addArrangedSubview(continueButton)
        updateContinueTitle(content.continueTitle)
    }

    func renderChoices(_ choices: [SetupChoiceViewModel]) {
        choiceStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, model) in choices.enumerated() {
            let choice = ChoiceRowView(title: model.title, hint: model.hint, selected: model.selected)
            choice.addAction(UIAction { [weak self] _ in self?.presenter?.selectChoice(at: index) }, for: .touchUpInside)
            choiceStack.addArrangedSubview(choice)
        }
    }

    func renderDetail(_ detail: StepperViewModel?) {
        detailHost.arrangedSubviews.forEach { $0.removeFromSuperview() }
        detailHost.isHidden = detail == nil
        guard let detail else { return }
        let card = CardView()
        let row = StepperSettingRow(title: detail.title, subtitle: detail.subtitle,
                                    range: detail.minimum...detail.maximum, step: detail.step,
                                    value: detail.value, format: detail.format)
        row.onChange = { [weak self, weak row] in
            guard let row else { return }
            self?.presenter?.detailChanged(row.value)
        }
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 4),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -4),
        ])
        detailHost.addArrangedSubview(card)
    }

    func updateContinueTitle(_ title: String) {
        continueButton.configuration?.title = title
    }

    func playSuccessFeedback() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
