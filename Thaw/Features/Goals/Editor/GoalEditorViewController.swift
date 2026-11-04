import UIKit

final class GoalEditorViewController: ScrollStackViewController, GoalEditorViewProtocol, UIAdaptivePresentationControllerDelegate {
    var presenter: GoalEditorPresenterProtocol?
    private let nameField = UITextField()
    private let targetField = UITextField()
    private let hintLabel = UILabel()
    private let errorLabel = UILabel()
    private let deadlineSwitch = UISwitch()
    private let datePicker = UIDatePicker()
    private let dateRow = UIStackView()

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func buildContent() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in
            self?.closeTapped()
        })
        navigationItem.leftBarButtonItem?.accessibilityLabel = "Close"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Save", style: .done, target: self, action: #selector(saveTapped))
        navigationItem.rightBarButtonItem?.isEnabled = false

        stack.addArrangedSubview(makeLabel("Name", font: ThawFont.body(13, weight: .medium), color: Theme.inkSecondary))
        configure(nameField, placeholder: "Espresso setup")
        nameField.autocapitalizationType = .sentences
        stack.addArrangedSubview(nameField)

        stack.addArrangedSubview(makeLabel("Target", font: ThawFont.body(13, weight: .medium), color: Theme.inkSecondary))
        configure(targetField, placeholder: "S$0")
        targetField.keyboardType = .decimalPad
        stack.addArrangedSubview(targetField)

        hintLabel.font = ThawFont.body(13)
        hintLabel.numberOfLines = 0
        hintLabel.adjustsFontForContentSizeCategory = true
        stack.addArrangedSubview(hintLabel)

        stack.addArrangedSubview(makeDeadlineCard())

        errorLabel.font = ThawFont.body(13)
        errorLabel.textColor = Theme.destructive
        errorLabel.numberOfLines = 0
        errorLabel.adjustsFontForContentSizeCategory = true
        errorLabel.isHidden = true
        stack.addArrangedSubview(errorLabel)
        presenter?.viewDidLoad()
    }

    private func makeDeadlineCard() -> UIView {
        let card = CardView()
        let title = makeLabel("Deadline", font: ThawFont.body(16))
        let subtitle = makeLabel("Optional. Missed deadlines move to the next payday.", font: ThawFont.body(13), color: Theme.inkSecondary)
        let text = UIStackView(arrangedSubviews: [title, subtitle])
        text.axis = .vertical
        text.spacing = 2
        deadlineSwitch.onTintColor = Theme.accent
        deadlineSwitch.accessibilityLabel = "Deadline"
        deadlineSwitch.setContentHuggingPriority(.required, for: .horizontal)
        deadlineSwitch.addAction(UIAction { [weak self] _ in self?.deadlineToggled() }, for: .valueChanged)
        let top = AdaptiveStackView(arrangedSubviews: [text, deadlineSwitch])
        top.spacing = 12
        top.compactAlignment = .center

        let dateTitle = makeLabel("Date", font: ThawFont.body(16))
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .compact
        datePicker.tintColor = Theme.accent
        datePicker.accessibilityLabel = "Deadline date"
        datePicker.addAction(UIAction { [weak self] _ in self?.inputDidChange() }, for: .valueChanged)
        dateRow.addArrangedSubview(dateTitle)
        dateRow.addArrangedSubview(UIView())
        dateRow.addArrangedSubview(datePicker)
        dateRow.alignment = .center
        dateRow.isHidden = true

        let content = UIStackView(arrangedSubviews: [top, dateRow])
        content.axis = .vertical
        content.spacing = 8
        content.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
        ])
        return card
    }

    private func configure(_ field: UITextField, placeholder: String) {
        field.placeholder = placeholder
        field.addAction(UIAction { [weak self, weak field] _ in
            if let field { self?.scrollToVisible(field) }
        }, for: .editingDidBegin)
        field.addAction(UIAction { [weak self] _ in self?.inputDidChange() }, for: .editingChanged)
        field.font = ThawFont.body(16)
        field.textColor = Theme.ink
        field.backgroundColor = Theme.surface
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = Theme.border.cgColor
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        field.leftViewMode = .always
        field.heightAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true
        field.adjustsFontForContentSizeCategory = true
    }

    private var input: GoalEditorInput {
        GoalEditorInput(name: nameField.text ?? "", target: targetField.text ?? "",
                        hasDeadline: deadlineSwitch.isOn, deadline: datePicker.date)
    }

    private func inputDidChange() {
        errorLabel.isHidden = true
        presenter?.inputChanged(input)
    }

    private func deadlineToggled() {
        dateRow.isHidden = !deadlineSwitch.isOn
        view.endEditing(true)
        inputDidChange()
    }

    func render(_ model: GoalEditorViewModel) {
        title = model.title
        nameField.text = model.input.name
        targetField.text = model.input.target
        datePicker.minimumDate = model.minimumDate
        datePicker.date = model.input.deadline
        deadlineSwitch.isOn = model.input.hasDeadline
        dateRow.isHidden = !model.input.hasDeadline
    }

    func setSaveEnabled(_ isEnabled: Bool) {
        navigationItem.rightBarButtonItem?.isEnabled = isEnabled
    }

    func setHint(_ text: String, isWarning: Bool) {
        hintLabel.text = text
        hintLabel.textColor = isWarning ? Theme.destructive : Theme.inkSecondary
    }

    func setModalInPresentation(_ isModal: Bool) {
        isModalInPresentation = isModal
        navigationController?.isModalInPresentation = isModal
    }

    func showError(_ message: String) {
        errorLabel.text = message
        errorLabel.isHidden = false
        scrollToVisible(errorLabel)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.presentationController?.delegate = self
    }

    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        presenter?.didAttemptDismiss(input)
    }

    private func closeTapped() {
        presenter?.tapClose(input)
    }

    func showDiscardConfirmation() {
        guard presentedViewController == nil else { return }
        let sheet = UIAlertController(title: "Discard changes?", message: "Your edits to this goal won't be saved.",
                                      preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Discard changes", style: .destructive) { [weak self] _ in
            self?.presenter?.confirmDiscard()
        })
        sheet.addAction(UIAlertAction(title: "Keep editing", style: .cancel))
        sheet.popoverPresentationController?.sourceItem = navigationItem.leftBarButtonItem
        present(sheet, animated: true)
    }

    override func accessibilityPerformEscape() -> Bool {
        closeTapped()
        return true
    }

    @objc private func saveTapped() {
        presenter?.tapSave(input)
    }
}
