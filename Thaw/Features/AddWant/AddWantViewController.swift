import UIKit

final class AddWantViewController: ScrollStackViewController, AddWantViewProtocol, UITextViewDelegate, UIAdaptivePresentationControllerDelegate {
    var presenter: AddWantPresenterProtocol?
    private let nameField = UITextField()
    private let priceField = UITextField()
    private let reasonView = UITextView()
    private let errorLabel = UILabel()
    private let noteLabel = UILabel()
    private var discardTitle = "Discard this want?"
    private var discardMessage = "What you typed won't be saved."

    init() {
        super.init(nibName: nil, bundle: nil)
        title = "Add to Thaw"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func buildContent() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel, primaryAction: UIAction { [weak self] _ in
            self?.cancelTapped()
        })
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Add to Thaw", style: .done, target: self, action: #selector(saveTapped))

        stack.addArrangedSubview(makeLabel("What do you want?", font: ThawFont.body(13, weight: .medium), color: Theme.inkSecondary))
        configure(nameField, placeholder: "Noise-cancelling headphones")
        stack.addArrangedSubview(nameField)

        stack.addArrangedSubview(makeLabel("Price", font: ThawFont.body(13, weight: .medium), color: Theme.inkSecondary))
        configure(priceField, placeholder: "S$0")
        priceField.keyboardType = .decimalPad
        stack.addArrangedSubview(priceField)

        stack.addArrangedSubview(makeLabel("Why do you want it? In your words.", font: ThawFont.body(13, weight: .medium), color: Theme.inkSecondary))
        reasonView.delegate = self
        reasonView.font = ThawFont.body(16)
        reasonView.textColor = Theme.ink
        reasonView.backgroundColor = Theme.surface
        reasonView.layer.cornerRadius = 12
        reasonView.layer.borderWidth = 1
        reasonView.layer.borderColor = Theme.border.cgColor
        reasonView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        reasonView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true
        reasonView.adjustsFontForContentSizeCategory = true
        stack.addArrangedSubview(reasonView)

        noteLabel.font = ThawFont.body(13)
        noteLabel.textColor = Theme.inkSecondary
        noteLabel.numberOfLines = 0
        noteLabel.adjustsFontForContentSizeCategory = true
        stack.addArrangedSubview(noteLabel)

        errorLabel.font = ThawFont.body(13)
        errorLabel.textColor = .systemRed
        errorLabel.numberOfLines = 0
        errorLabel.adjustsFontForContentSizeCategory = true
        errorLabel.isHidden = true
        stack.addArrangedSubview(errorLabel)
        presenter?.viewDidLoad()
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

    private var input: AddWantInput {
        AddWantInput(name: nameField.text ?? "", price: priceField.text ?? "", reason: reasonView.text ?? "")
    }

    private func inputDidChange() {
        presenter?.inputChanged(input)
    }

    func setModalInPresentation(_ isModal: Bool) {
        isModalInPresentation = isModal
        navigationController?.isModalInPresentation = isModal
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        scrollToVisible(textView)
    }

    func textViewDidChange(_ textView: UITextView) {
        inputDidChange()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.presentationController?.delegate = self
    }

    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        presenter?.didAttemptDismiss(input)
    }

    private func cancelTapped() {
        presenter?.tapCancel(input)
    }

    func showDiscardConfirmation() {
        guard presentedViewController == nil else { return }
        let sheet = UIAlertController(title: discardTitle, message: discardMessage,
                                      preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Discard", style: .destructive) { [weak self] _ in
            self?.presenter?.confirmDiscard()
        })
        sheet.addAction(UIAlertAction(title: "Keep editing", style: .cancel))
        sheet.popoverPresentationController?.sourceItem = navigationItem.leftBarButtonItem
        present(sheet, animated: true)
    }

    override func accessibilityPerformEscape() -> Bool {
        cancelTapped()
        return true
    }

    @objc private func saveTapped() {
        presenter?.tapSave(input)
    }

    func configure(_ screen: AddWantScreen) {
        title = screen.title
        navigationItem.rightBarButtonItem?.title = screen.actionTitle
        discardTitle = screen.discardTitle
        discardMessage = screen.discardMessage
        if let initial = screen.initial {
            nameField.text = initial.name
            priceField.text = initial.price
            reasonView.text = initial.reason
        }
    }

    func render(note: String) {
        noteLabel.text = note
    }

    func showSavedMoment(line: String, completion: @escaping () -> Void) {
        view.endEditing(true)
        navigationItem.leftBarButtonItem?.isEnabled = false
        navigationItem.rightBarButtonItem?.isEnabled = false
        MomentView.present(on: view, mood: .frozen, line: line, completion: completion)
    }

    func showError(_ message: String) {
        errorLabel.text = message
        errorLabel.isHidden = false
        scrollToVisible(errorLabel)
    }
}
