import UIKit

final class AddWantViewController: ScrollStackViewController {
    private let store: WantStore
    private let reminders: Reminders
    private let onSave: () -> Void
    private let nameField = UITextField()
    private let priceField = UITextField()
    private let reasonView = UITextView()
    private let errorLabel = UILabel()

    init(store: WantStore, reminders: Reminders, onSave: @escaping () -> Void) {
        self.store = store
        self.reminders = reminders
        self.onSave = onSave
        super.init(nibName: nil, bundle: nil)
        title = "Add to Thaw"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func buildContent() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Add to Thaw", style: .done, target: self, action: #selector(saveTapped))

        stack.addArrangedSubview(makeLabel("What do you want?", font: ThawFont.body(13, weight: .medium), color: Theme.inkSecondary))
        configure(nameField, placeholder: "Noise-cancelling headphones")
        stack.addArrangedSubview(nameField)

        stack.addArrangedSubview(makeLabel("Price", font: ThawFont.body(13, weight: .medium), color: Theme.inkSecondary))
        configure(priceField, placeholder: "S$0")
        priceField.keyboardType = .decimalPad
        stack.addArrangedSubview(priceField)

        stack.addArrangedSubview(makeLabel("Why do you want it? In your words.", font: ThawFont.body(13, weight: .medium), color: Theme.inkSecondary))
        reasonView.font = ThawFont.body(16)
        reasonView.textColor = Theme.ink
        reasonView.backgroundColor = Theme.surface
        reasonView.layer.cornerRadius = 12
        reasonView.layer.borderWidth = 1
        reasonView.layer.borderColor = Theme.border.cgColor
        reasonView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        reasonView.heightAnchor.constraint(equalToConstant: 120).isActive = true
        stack.addArrangedSubview(reasonView)

        let note = makeLabel(
            "Thaw will read this back to you when it thaws. Items under S$30 use a 2-day timer; the rest thaw on payday.",
            font: ThawFont.body(13),
            color: Theme.inkSecondary
        )
        stack.addArrangedSubview(note)

        errorLabel.font = ThawFont.body(13)
        errorLabel.textColor = .systemRed
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true
        stack.addArrangedSubview(errorLabel)
    }

    private func configure(_ field: UITextField, placeholder: String) {
        field.placeholder = placeholder
        field.font = ThawFont.body(16)
        field.textColor = Theme.ink
        field.backgroundColor = Theme.surface
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = Theme.border.cgColor
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        field.leftViewMode = .always
        field.heightAnchor.constraint(equalToConstant: 50).isActive = true
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func saveTapped() {
        let name = nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !name.isEmpty else { return showError("Add a name for the item.") }
        guard let price = Decimal(string: priceField.text ?? ""), price > 0 else {
            return showError("Enter a price above S$0.")
        }
        store.add(name: name, price: price, reason: reasonView.text ?? "")
        reminders.refresh(requestingPermission: true)
        onSave()
        dismiss(animated: true)
    }

    private func showError(_ message: String) {
        errorLabel.text = message
        errorLabel.isHidden = false
    }
}
