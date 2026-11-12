import UIKit

final class AddWantViewController: ScrollStackViewController, AddWantViewProtocol, UITextViewDelegate, UIAdaptivePresentationControllerDelegate {
    var presenter: AddWantPresenterProtocol?
    private let nameField = UITextField()
    private let priceField = UITextField()
    private let reasonView = UITextView()
    private let errorLabel = UILabel()
    private let thawLabel = UILabel()
    private let reasonPlaceholder = UILabel()
    private let statusRow = UIStackView()
    private let statusButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)
    private var statusOptions: [AddWantStatusOption] = []
    private var selectedStatus: Want.Status?
    private let captionLabel = UILabel()
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

        captionLabel.font = ThawFont.body(13, weight: .medium)
        captionLabel.textColor = Theme.inkSecondary
        captionLabel.numberOfLines = 0
        captionLabel.adjustsFontForContentSizeCategory = true
        captionLabel.isHidden = true
        stack.addArrangedSubview(captionLabel)

        configure(nameField, placeholder: "What do you want?")
        configure(priceField, placeholder: "0")
        nameField.accessibilityLabel = "Name"
        nameField.accessibilityIdentifier = "addwant.name"
        nameField.autocapitalizationType = .sentences
        priceField.accessibilityLabel = "Price in Singapore dollars"
        priceField.accessibilityIdentifier = "addwant.price"
        priceField.keyboardType = .decimalPad
        let prefix = makeLabel("S$", font: ThawFont.body(16), color: Theme.inkSecondary)
        prefix.isAccessibilityElement = false
        let prefixBox = UIView()
        prefixBox.addSubview(prefix)
        prefix.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            prefix.leadingAnchor.constraint(equalTo: prefixBox.leadingAnchor, constant: 14),
            prefix.trailingAnchor.constraint(equalTo: prefixBox.trailingAnchor, constant: -4),
            prefix.centerYAnchor.constraint(equalTo: prefixBox.centerYAnchor),
            prefix.topAnchor.constraint(greaterThanOrEqualTo: prefixBox.topAnchor),
            prefix.bottomAnchor.constraint(lessThanOrEqualTo: prefixBox.bottomAnchor),
        ])
        priceField.leftView = prefixBox
        priceField.widthAnchor.constraint(equalToConstant: 120).isActive = true
        let nameAndPrice = AdaptiveStackView(arrangedSubviews: [nameField, priceField])
        nameAndPrice.compactAlignment = .top
        nameAndPrice.spacing = 12
        nameAndPrice.distribution = .fill
        stack.addArrangedSubview(nameAndPrice)

        thawLabel.font = ThawFont.body(13)
        thawLabel.textColor = Theme.inkSecondary
        thawLabel.numberOfLines = 0
        thawLabel.adjustsFontForContentSizeCategory = true
        thawLabel.accessibilityIdentifier = "addwant.thaw"
        thawLabel.isHidden = true
        stack.addArrangedSubview(thawLabel)

        stack.addArrangedSubview(makeLabel("Why?", font: ThawFont.body(13, weight: .medium), color: Theme.inkSecondary))
        reasonView.delegate = self
        reasonView.accessibilityLabel = "Why?"
        reasonView.accessibilityIdentifier = "addwant.reason"
        reasonView.font = ThawFont.body(16)
        reasonView.textColor = Theme.ink
        reasonView.backgroundColor = Theme.surface
        reasonView.layer.cornerRadius = 12
        reasonView.layer.borderWidth = 1
        reasonView.layer.borderColor = Theme.controlBorder.cgColor
        reasonView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        reasonView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true
        reasonView.adjustsFontForContentSizeCategory = true
        stack.addArrangedSubview(reasonView)

        reasonPlaceholder.text = "In your words. Thaw reads it back when it thaws."
        reasonPlaceholder.font = ThawFont.body(16)
        reasonPlaceholder.textColor = Theme.inkSecondary
        reasonPlaceholder.numberOfLines = 0
        reasonPlaceholder.adjustsFontForContentSizeCategory = true
        reasonPlaceholder.isAccessibilityElement = false
        reasonPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        reasonView.addSubview(reasonPlaceholder)
        NSLayoutConstraint.activate([
            reasonPlaceholder.topAnchor.constraint(equalTo: reasonView.topAnchor, constant: 12),
            reasonPlaceholder.leadingAnchor.constraint(equalTo: reasonView.leadingAnchor, constant: 17),
            reasonPlaceholder.trailingAnchor.constraint(equalTo: reasonView.frameLayoutGuide.trailingAnchor, constant: -17),
        ])

        buildStatusRow()

        errorLabel.font = ThawFont.body(13)
        errorLabel.textColor = Theme.destructive
        errorLabel.numberOfLines = 0
        errorLabel.adjustsFontForContentSizeCategory = true
        errorLabel.isHidden = true
        stack.addArrangedSubview(errorLabel)

        var deleteConfig = UIButton.Configuration.plain()
        deleteConfig.baseForegroundColor = Theme.destructive
        deleteConfig.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        deleteConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var attrs = attrs
            attrs.font = ThawFont.body(16, weight: .semibold)
            return attrs
        }
        deleteButton.configuration = deleteConfig
        deleteButton.accessibilityIdentifier = "addwant.delete"
        deleteButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        deleteButton.addAction(UIAction { [weak self] _ in self?.presenter?.tapDelete() }, for: .touchUpInside)
        deleteButton.isHidden = true
        stack.addArrangedSubview(deleteButton)
        stack.setCustomSpacing(40, after: errorLabel)
        presenter?.viewDidLoad()
    }

    private func buildStatusRow() {
        statusRow.axis = .vertical
        statusRow.spacing = Theme.Spacing.gap
        statusRow.isHidden = true
        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = Theme.ink
        config.image = UIImage(systemName: "chevron.up.chevron.down")
        config.imagePlacement = .trailing
        config.imagePadding = 8
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
        config.titleAlignment = .leading
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var attrs = attrs
            attrs.font = ThawFont.body(16)
            return attrs
        }
        statusButton.configuration = config
        statusButton.contentHorizontalAlignment = .fill
        statusButton.backgroundColor = Theme.surface
        statusButton.layer.cornerRadius = 12
        statusButton.layer.borderWidth = 1
        statusButton.layer.borderColor = Theme.controlBorder.cgColor
        statusButton.showsMenuAsPrimaryAction = true
        statusButton.accessibilityIdentifier = "addwant.status"
        statusButton.accessibilityLabel = "Status"
        statusButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true
        statusRow.addArrangedSubview(makeLabel("Status", font: ThawFont.body(13, weight: .medium), color: Theme.inkSecondary))
        statusRow.addArrangedSubview(statusButton)
        stack.addArrangedSubview(statusRow)
    }

    private func refreshStatusMenu() {
        let current = statusOptions.first { $0.status == selectedStatus }
        statusButton.configuration?.title = current?.title
        statusButton.accessibilityValue = current?.title
        statusButton.menu = UIMenu(children: statusOptions.map { option in
            UIAction(title: option.title, state: option.status == selectedStatus ? .on : .off) { [weak self] _ in
                self?.selectedStatus = option.status
                self?.refreshStatusMenu()
                self?.inputDidChange()
            }
        })
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
        field.layer.borderColor = Theme.controlBorder.cgColor
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        field.leftViewMode = .always
        field.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [.foregroundColor: Theme.inkSecondary])
        field.heightAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true
        field.adjustsFontForContentSizeCategory = true
    }

    private var input: AddWantInput {
        AddWantInput(name: nameField.text ?? "", price: priceField.text ?? "", reason: reasonView.text ?? "", status: selectedStatus)
    }

    private func inputDidChange() {
        presenter?.inputChanged(input)
    }

    func setModalInPresentation(_ isModal: Bool) {
        // Walk up containers too: in the share extension the form sits inside a child navigation controller.
        var controller: UIViewController? = self
        while let current = controller {
            current.isModalInPresentation = isModal
            controller = current.parent
        }
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        scrollToVisible(textView)
    }

    func textViewDidChange(_ textView: UITextView) {
        reasonPlaceholder.isHidden = !textView.text.isEmpty
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

    func showDeleteConfirmation(_ confirmation: AddWantDeleteConfirmation) {
        guard presentedViewController == nil else { return }
        let alert = UIAlertController(title: confirmation.title, message: confirmation.message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: confirmation.cancelTitle, style: .cancel))
        alert.addAction(UIAlertAction(title: confirmation.deleteTitle, style: .destructive) { [weak self] _ in
            self?.presenter?.confirmDelete()
        })
        present(alert, animated: true)
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
        captionLabel.text = screen.caption
        captionLabel.isHidden = screen.caption == nil
        statusOptions = screen.statusOptions
        selectedStatus = screen.initial?.status
        statusRow.isHidden = statusOptions.isEmpty
        refreshStatusMenu()
        deleteButton.configuration?.title = screen.deleteTitle
        deleteButton.isHidden = screen.deleteTitle == nil
        if let initial = screen.initial {
            nameField.text = initial.name
            priceField.text = initial.price
            reasonView.text = initial.reason
            reasonPlaceholder.isHidden = !initial.reason.isEmpty
        }
    }

    func render(thawLine: String?) {
        thawLabel.text = thawLine
        thawLabel.isHidden = thawLine == nil
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
