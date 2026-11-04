import UIKit

final class PaydaySetupViewController: ScrollStackViewController, PaydaySetupViewProtocol {
    var presenter: PaydaySetupPresenterProtocol?
    private var isOnboarding = false
    private var currentSaveTitle = "Save"

    private let choiceStack = UIStackView()
    private let detailHost = UIStackView()
    private let saveButton = PillButton(title: "Save", style: .primary)
    private var resetTitleWork: DispatchWorkItem?

    init() {
        super.init(nibName: nil, bundle: nil)
        title = "Settings"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func buildContent() {
        navigationItem.largeTitleDisplayMode = .never
        stack.spacing = 16
        presenter?.viewDidLoad()
    }

    func render(_ content: PaydaySetupContent) {
        isOnboarding = content.isOnboarding
        let heading = makeLabel("When's payday?", font: ThawFont.display(34))
        heading.accessibilityTraits = .header
        let subtitle = makeLabel("Wants thaw then, when you can actually afford them.",
                                 font: ThawFont.body(15), color: Theme.inkSecondary)
        let intro = UIStackView(arrangedSubviews: [heading, subtitle])
        intro.axis = .vertical
        intro.spacing = 6
        stack.addArrangedSubview(intro)

        let legend = makeLabel("I get paid", font: ThawFont.body(13, weight: .bold), color: Theme.inkSecondary)
        stack.addArrangedSubview(legend)
        stack.setCustomSpacing(8, after: legend)
        choiceStack.axis = .vertical
        choiceStack.spacing = 8
        stack.addArrangedSubview(choiceStack)
        renderChoices(content.choices)

        stack.addArrangedSubview(makeSettingsCard(content))

        let footer = makeLabel("Entered by you, kept on this phone. Thaw never reads your bank.",
                               font: ThawFont.body(13), color: Theme.inkSecondary)
        footer.textAlignment = .center
        stack.addArrangedSubview(footer)

        if content.isOnboarding {
            let notice = makeLabel("We'll ask to send payday reminders next.",
                                   font: ThawFont.body(13), color: Theme.inkSecondary)
            notice.textAlignment = .center
            stack.addArrangedSubview(notice)
        }
        saveButton.addAction(UIAction { [weak self] _ in self?.presenter?.tapSave() }, for: .touchUpInside)
        stack.addArrangedSubview(saveButton)
        updateSaveTitle(content.saveTitle)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(isOnboarding, animated: false)
    }

    // MARK: Choices

    func renderChoices(_ choices: [SetupChoiceViewModel]) {
        choiceStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, model) in choices.enumerated() {
            let choice = ChoiceRowView(title: model.title, hint: model.hint, selected: model.selected)
            choice.addAction(UIAction { [weak self] _ in self?.presenter?.selectChoice(at: index) }, for: .touchUpInside)
            choiceStack.addArrangedSubview(choice)
        }
    }

    // MARK: Settings card

    private func makeSettingsCard(_ content: PaydaySetupContent) -> UIView {
        let card = CardView()
        let rows = UIStackView()
        rows.axis = .vertical
        rows.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(rows)
        NSLayoutConstraint.activate([
            rows.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            rows.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            rows.topAnchor.constraint(equalTo: card.topAnchor, constant: 4),
            rows.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -4),
        ])

        detailHost.axis = .vertical
        rows.addArrangedSubview(detailHost)
        renderDetail(content.detail)

        let presenter = presenter
        let all = [
            makeStepper(content.review) { presenter?.reviewChanged($0) },
            makeStepper(content.funMoney) { presenter?.funMoneyChanged($0) },
            makeStepper(content.timerThreshold) { presenter?.timerThresholdChanged($0) },
            makeStepper(content.timerLength) { presenter?.timerLengthChanged($0) },
        ]
        for (index, row) in all.enumerated() {
            rows.addArrangedSubview(row)
            if index < all.count - 1 { rows.addArrangedSubview(Self.separator()) }
        }
        return card
    }

    private func makeStepper(_ model: StepperViewModel, onChange: @escaping (Double) -> Void) -> StepperSettingRow {
        let row = StepperSettingRow(title: model.title, subtitle: model.subtitle, range: model.minimum...model.maximum,
                                    step: model.step, value: model.value, format: model.format)
        row.onChange = { [weak row] in
            guard let row else { return }
            onChange(row.value)
        }
        return row
    }

    func renderDetail(_ detail: StepperViewModel?) {
        detailHost.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard let detail else { return }
        let presenter = presenter
        detailHost.addArrangedSubview(makeStepper(detail) { presenter?.detailChanged($0) })
        detailHost.addArrangedSubview(Self.separator())
    }

    // MARK: Save

    func updateSaveTitle(_ title: String) {
        currentSaveTitle = title
        saveButton.configuration?.title = title
    }

    func playSuccessFeedback() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func showSavedConfirmation() {
        saveButton.configuration?.title = "Saved"
        resetTitleWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.saveButton.configuration?.title = self.currentSaveTitle
        }
        resetTitleWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    private static func separator() -> UIView {
        let line = UIView()
        line.backgroundColor = UIColor(hex: 0xEDF2F5)
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return line
    }
}
