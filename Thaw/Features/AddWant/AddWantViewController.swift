import UIKit

final class AddWantViewController: ScrollStackViewController, AddWantViewProtocol, UITextViewDelegate, UIAdaptivePresentationControllerDelegate {
    var presenter: AddWantPresenterProtocol?
    /// A text view, not a field, so long names wrap instead of being clipped at large text sizes. Newlines are
    /// kept out of it.
    private let nameField = UITextView()
    private let priceField = UITextField()
    private let reasonView = UITextView()
    private let errorLabel = UILabel()
    private let thawLabel = UILabel()
    private let reasonPlaceholder = UILabel()
    private let namePlaceholder = UILabel()
    private let statusRow = UIStackView()
    private let statusButton = UIButton(type: .system)
    private let saveButton = PillButton(title: "Save", style: .primary)
    private let deleteButton = PillButton(title: "Delete", style: .destructive)
    /// Keeps the gap above Delete: custom spacing after a hidden view (the error label) is dropped.
    private let deleteGap = UIView()
    private var thawAnnouncement: Task<Void, Never>?
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

    /// Space between the last field (or the error) and Delete.
    static let deleteSpacing: CGFloat = 40

    override func buildContent() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel, primaryAction: UIAction { [weak self] _ in
            self?.cancelTapped()
        })

        captionLabel.font = ThawFont.body(13, weight: .medium)
        captionLabel.adjustsFontForContentSizeCategory = true
        captionLabel.textColor = Theme.inkSecondary
        captionLabel.numberOfLines = 0
        captionLabel.isHidden = true
        stack.addArrangedSubview(captionLabel)

        configureNameField()
        configure(priceField, placeholder: "0")
        nameField.accessibilityLabel = "Name"
        nameField.accessibilityIdentifier = "addwant.name"
        nameField.autocapitalizationType = .sentences
        nameField.returnKeyType = .next
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
        // Below required, so the price takes the full width once the pair stacks at accessibility sizes.
        let priceWidth = priceField.widthAnchor.constraint(equalToConstant: 120)
        priceWidth.priority = .defaultHigh
        priceWidth.isActive = true
        let doneBar = UIToolbar()
        doneBar.items = [UIBarButtonItem(systemItem: .flexibleSpace),
                         UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in self?.view.endEditing(true) })]
        doneBar.sizeToFit()
        priceField.inputAccessoryView = doneBar
        let nameAndPrice = AdaptiveStackView(arrangedSubviews: [nameField, priceField])
        nameAndPrice.compactAlignment = .top
        nameAndPrice.largeAlignment = .fill
        nameAndPrice.spacing = 12
        nameAndPrice.distribution = .fill
        stack.addArrangedSubview(nameAndPrice)

        thawLabel.font = ThawFont.body(13)
        thawLabel.adjustsFontForContentSizeCategory = true
        thawLabel.textColor = Theme.inkSecondary
        thawLabel.numberOfLines = 0
        thawLabel.accessibilityIdentifier = "addwant.thaw"
        thawLabel.isHidden = true
        stack.addArrangedSubview(thawLabel)

        reasonView.delegate = self
        reasonView.accessibilityLabel = "Why?"
        reasonView.accessibilityIdentifier = "addwant.reason"
        reasonView.font = ThawFont.body(16)
        reasonView.adjustsFontForContentSizeCategory = true
        reasonView.textColor = Theme.ink
        reasonView.backgroundColor = Theme.surface
        reasonView.layer.cornerRadius = 12
        reasonView.layer.borderWidth = 1
        reasonView.setBorderColor(Theme.controlBorder)
        reasonView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        reasonView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true
        stack.addArrangedSubview(reasonView)

        reasonPlaceholder.text = "Why?"
        reasonPlaceholder.font = ThawFont.body(16)
        reasonPlaceholder.adjustsFontForContentSizeCategory = true
        reasonPlaceholder.textColor = Theme.inkSecondary
        reasonPlaceholder.numberOfLines = 0
        reasonPlaceholder.isAccessibilityElement = false
        reasonPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        reasonView.addSubview(reasonPlaceholder)
        NSLayoutConstraint.activate([
            reasonPlaceholder.topAnchor.constraint(equalTo: reasonView.topAnchor, constant: 12),
            reasonPlaceholder.leadingAnchor.constraint(equalTo: reasonView.leadingAnchor, constant: 17),
            reasonPlaceholder.trailingAnchor.constraint(equalTo: reasonView.frameLayoutGuide.trailingAnchor, constant: -17),
            // Grows the box at large text sizes so the placeholder isn't cut off.
            reasonPlaceholder.bottomAnchor.constraint(lessThanOrEqualTo: reasonView.frameLayoutGuide.bottomAnchor, constant: -12),
        ])

        buildStatusRow()

        errorLabel.font = ThawFont.body(13)
        errorLabel.adjustsFontForContentSizeCategory = true
        errorLabel.textColor = Theme.destructive
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true
        stack.addArrangedSubview(errorLabel)

        saveButton.accessibilityIdentifier = "addwant.save"
        saveButton.addAction(UIAction { [weak self] _ in self?.saveTapped() }, for: .touchUpInside)
        stack.addArrangedSubview(saveButton)
        deleteButton.accessibilityIdentifier = "addwant.delete"
        deleteButton.addAction(UIAction { [weak self] _ in self?.presenter?.tapDelete() }, for: .touchUpInside)
        deleteButton.isHidden = true
        deleteGap.isHidden = true
        deleteGap.heightAnchor.constraint(equalToConstant: Self.deleteSpacing - stack.spacing).isActive = true
        stack.addArrangedSubview(deleteGap)
        stack.setCustomSpacing(0, after: deleteGap)
        stack.addArrangedSubview(deleteButton)
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
        statusButton.setBorderColor(Theme.controlBorder)
        statusButton.showsMenuAsPrimaryAction = true
        statusButton.accessibilityIdentifier = "addwant.status"
        statusButton.accessibilityLabel = "Status"
        statusButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true
        let caption = makeLabel("Status", font: ThawFont.body(13, weight: .medium), color: Theme.inkSecondary)
        // The button below is already labelled "Status", so VoiceOver would read it twice.
        caption.isAccessibilityElement = false
        statusRow.addArrangedSubview(caption)
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

    private func configureNameField() {
        nameField.delegate = self
        nameField.font = ThawFont.body(16)
        nameField.adjustsFontForContentSizeCategory = true
        nameField.textColor = Theme.ink
        nameField.backgroundColor = Theme.surface
        nameField.layer.cornerRadius = 12
        nameField.layer.borderWidth = 1
        nameField.setBorderColor(Theme.controlBorder)
        nameField.isScrollEnabled = false
        // 14 pt to the text, like the price field: 9 pt inset plus the text container's 5 pt line padding.
        nameField.textContainerInset = UIEdgeInsets(top: 15, left: 9, bottom: 15, right: 9)
        nameField.heightAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true
        nameField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        nameField.setContentHuggingPriority(.defaultLow, for: .horizontal)

        namePlaceholder.text = "What do you want?"
        namePlaceholder.font = ThawFont.body(16)
        namePlaceholder.adjustsFontForContentSizeCategory = true
        namePlaceholder.textColor = Theme.inkSecondary
        namePlaceholder.numberOfLines = 0
        namePlaceholder.isAccessibilityElement = false
        namePlaceholder.isUserInteractionEnabled = false
        namePlaceholder.translatesAutoresizingMaskIntoConstraints = false
        nameField.addSubview(namePlaceholder)
        NSLayoutConstraint.activate([
            namePlaceholder.leadingAnchor.constraint(equalTo: nameField.frameLayoutGuide.leadingAnchor, constant: 14),
            namePlaceholder.trailingAnchor.constraint(lessThanOrEqualTo: nameField.frameLayoutGuide.trailingAnchor, constant: -14),
            namePlaceholder.topAnchor.constraint(equalTo: nameField.frameLayoutGuide.topAnchor, constant: 15),
            namePlaceholder.bottomAnchor.constraint(lessThanOrEqualTo: nameField.frameLayoutGuide.bottomAnchor, constant: -15),
        ])
    }

    private func updateNamePlaceholder() {
        namePlaceholder.isHidden = !(nameField.text ?? "").isEmpty
    }

    private func configure(_ field: UITextField, placeholder: String) {
        field.addAction(UIAction { [weak self, weak field] _ in
            if let field { self?.scrollToVisible(field) }
        }, for: .editingDidBegin)
        field.addAction(UIAction { [weak self] _ in self?.inputDidChange() }, for: .editingChanged)
        field.font = ThawFont.body(16)
        field.adjustsFontForContentSizeCategory = true
        field.textColor = Theme.ink
        field.backgroundColor = Theme.surface
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.setBorderColor(Theme.controlBorder)
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        field.leftViewMode = .always
        field.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [.foregroundColor: Theme.inkSecondary])
        field.heightAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true
    }

    private var input: AddWantInput {
        AddWantInput(name: nameField.text ?? "", price: priceField.text ?? "", reason: reasonView.text ?? "", status: selectedStatus)
    }

    private func inputDidChange() {
        errorLabel.isHidden = true
        updateNamePlaceholder()
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
        if textView === reasonView { reasonPlaceholder.isHidden = !textView.text.isEmpty }
        inputDidChange()
    }

    /// The name is one line of data even when it wraps: Return moves on to the price, pasted newlines become spaces.
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard textView === nameField, text.contains(where: \.isNewline) else { return true }
        if text == "\n" {
            priceField.becomeFirstResponder()
            return false
        }
        let cleaned = text.components(separatedBy: .newlines).joined(separator: " ")
        if let current = textView.text, let swap = Range(range, in: current) {
            textView.text = current.replacingCharacters(in: swap, with: cleaned)
            textViewDidChange(textView)
        }
        return false
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

    private func saveTapped() {
        presenter?.tapSave(input)
    }

    func configure(_ screen: AddWantScreen) {
        title = screen.title
        saveButton.configuration?.title = screen.actionTitle
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
        deleteGap.isHidden = deleteButton.isHidden
        if let initial = screen.initial {
            nameField.text = initial.name
            updateNamePlaceholder()
            priceField.text = initial.price
            reasonView.text = initial.reason
            reasonPlaceholder.isHidden = !initial.reason.isEmpty
        }
    }

    func render(thawLine: String?) {
        let changed = thawLine != thawLabel.text
        thawLabel.text = thawLine
        thawLabel.isHidden = thawLine == nil
        if changed, isViewLoaded, view.window != nil { announceThawLine() }
    }

    /// Reads the thaw line out once typing settles, so VoiceOver doesn't speak every keystroke.
    private func announceThawLine() {
        thawAnnouncement?.cancel()
        thawAnnouncement = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, let self, let line = self.thawLabel.text, !self.thawLabel.isHidden else { return }
            UIAccessibility.post(notification: .announcement, argument: line)
        }
    }

    func showSavedMoment(line: String, completion: @escaping () -> Void) {
        view.endEditing(true)
        navigationItem.leftBarButtonItem?.isEnabled = false
        saveButton.isEnabled = false
        deleteButton.isEnabled = false
        MomentView.present(on: view, mood: .frozen, line: line, completion: completion)
    }

    func showError(_ message: String) {
        errorLabel.text = message
        errorLabel.isHidden = false
        scrollToVisible(errorLabel)
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}
