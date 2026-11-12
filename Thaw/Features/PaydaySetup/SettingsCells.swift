import UIKit

enum SettingsListStyle {
    /// Inset-grouped list section, capped to the content column on wide screens.
    static func section(_ configuration: UICollectionLayoutListConfiguration,
                        environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        ThawColumn.insetGroupedSection(configuration, environment: environment)
    }

    static func listConfiguration(footer: Bool) -> UICollectionLayoutListConfiguration {
        var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        configuration.backgroundColor = Theme.background
        configuration.headerMode = .supplementary
        configuration.footerMode = footer ? .supplementary : .none
        return configuration
    }

    static func style(_ content: inout UIListContentConfiguration) {
        content.textProperties.font = ThawFont.body(17)
        content.textProperties.adjustsFontForContentSizeCategory = true
        content.textProperties.color = Theme.ink
        content.textProperties.adjustsFontForContentSizeCategory = true
        content.secondaryTextProperties.font = ThawFont.body(17)
        content.secondaryTextProperties.adjustsFontForContentSizeCategory = true
        content.secondaryTextProperties.color = Theme.inkSecondary
        content.secondaryTextProperties.adjustsFontForContentSizeCategory = true
    }

    static func styleSubtitle(_ content: inout UIListContentConfiguration) {
        style(&content)
        content.secondaryTextProperties.font = ThawFont.body(13)
        content.secondaryTextProperties.adjustsFontForContentSizeCategory = true
    }

    static func header(_ text: String?) -> UIListContentConfiguration {
        var content = UIListContentConfiguration.groupedHeader()
        content.text = text
        content.textProperties.font = ThawFont.body(13, weight: .semibold)
        content.textProperties.adjustsFontForContentSizeCategory = true
        content.textProperties.color = Theme.inkSecondary
        content.textProperties.adjustsFontForContentSizeCategory = true
        return content
    }

    static func footer(_ text: String?) -> UIListContentConfiguration {
        var content = UIListContentConfiguration.groupedFooter()
        content.text = text
        content.textProperties.font = ThawFont.body(13)
        content.textProperties.adjustsFontForContentSizeCategory = true
        content.textProperties.color = Theme.inkSecondary
        content.textProperties.adjustsFontForContentSizeCategory = true
        return content
    }
}

/// A list cell with a text area and a control; the control moves under the text at accessibility sizes.
class SettingsControlCell: UICollectionViewListCell {
    let textArea = UIListContentView(configuration: .valueCell())
    private let row = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        textArea.accessibilityElementsHidden = true
        textArea.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(textArea)
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)
        let guide = contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
        ])
        updateAxis()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: SettingsControlCell, _) in
            self.updateAxis()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func install(_ control: UIView) {
        control.setContentHuggingPriority(.required, for: .horizontal)
        control.setContentCompressionResistancePriority(.required, for: .horizontal)
        row.addArrangedSubview(control)
    }

    func setText(_ title: String, secondary: String? = nil) {
        var content = UIListContentConfiguration.valueCell()
        SettingsListStyle.style(&content)
        content.text = title
        content.secondaryText = secondary
        content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0)
        textArea.configuration = content
    }

    private func updateAxis() {
        let large = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        row.axis = large ? .vertical : .horizontal
        row.alignment = large ? .leading : .center
    }
}

/// Inline amount: right-aligned field, decimal pad, Done toolbar. Reports the raw text on end-editing.
final class SettingsAmountCell: SettingsControlCell, UITextFieldDelegate {
    let field = UITextField()
    var onEnd: ((String) -> Void)?
    private var displayText = ""
    private var editText = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        field.font = ThawFont.body(17, weight: .semibold)
        field.adjustsFontForContentSizeCategory = true
        field.textColor = Theme.accent
        field.textAlignment = .right
        field.keyboardType = .decimalPad
        field.delegate = self
        field.widthAnchor.constraint(greaterThanOrEqualToConstant: 88).isActive = true
        field.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        let toolbar = UIToolbar()
        toolbar.items = [
            UIBarButtonItem(systemItem: .flexibleSpace),
            UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in
                self?.field.resignFirstResponder()
            }),
        ]
        toolbar.sizeToFit()
        field.inputAccessoryView = toolbar
        install(field)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(_ model: SettingsRowViewModel, editText: String) {
        setText(model.title)
        displayText = model.value
        self.editText = editText
        field.accessibilityLabel = model.accessibilityLabel
        if !field.isFirstResponder { field.text = displayText }
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        textField.text = editText
        DispatchQueue.main.async { textField.selectAll(nil) }
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        let text = textField.text ?? ""
        textField.text = displayText
        onEnd?(text)
    }
}

final class SettingsStepperCell: SettingsControlCell {
    let stepper = UIStepper()
    var onChange: ((Int) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        stepper.stepValue = 1
        stepper.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.onChange?(Int(self.stepper.value))
        }, for: .valueChanged)
        install(stepper)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(_ model: SettingsRowViewModel, value: Int, minimum: Int, maximum: Int) {
        setText(model.title, secondary: model.value)
        stepper.minimumValue = Double(minimum)
        stepper.maximumValue = Double(maximum)
        stepper.value = Double(value)
        stepper.accessibilityLabel = model.accessibilityLabel
        stepper.accessibilityValue = model.accessibilityValue
    }
}

final class SettingsTimeCell: SettingsControlCell {
    let picker = UIDatePicker()
    var onChange: ((Int) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        picker.datePickerMode = .time
        picker.preferredDatePickerStyle = .compact
        picker.minuteInterval = 15
        picker.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            let parts = Calendar.current.dateComponents([.hour, .minute], from: self.picker.date)
            self.onChange?((parts.hour ?? 0) * 60 + (parts.minute ?? 0))
        }, for: .valueChanged)
        install(picker)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(_ model: SettingsRowViewModel, minutes: Int) {
        setText(model.title)
        picker.accessibilityLabel = model.accessibilityLabel
        let calendar = Calendar.current
        let current = calendar.dateComponents([.hour, .minute], from: picker.date)
        guard (current.hour ?? 0) * 60 + (current.minute ?? 0) != minutes,
              let date = calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now)
        else { return }
        picker.date = date
    }
}

/// A compact pop-up menu of numbers, for the payday rule's day.
final class SettingsMenuCell: SettingsControlCell {
    let button = UIButton(configuration: .gray())
    var onSelect: ((Int) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        button.showsMenuAsPrimaryAction = true
        button.changesSelectionAsPrimaryAction = true
        button.configuration?.baseForegroundColor = Theme.accent
        button.configuration?.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var updated = attributes
            updated.font = ThawFont.body(17, weight: .semibold)
            return updated
        }
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        install(button)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(_ model: RuleDayViewModel) {
        setText(model.title)
        button.accessibilityLabel = model.title
        let actions = model.options.enumerated().map { offset, title in
            let value = model.minimum + offset
            return UIAction(title: title, state: value == model.value ? .on : .off) { [weak self] _ in
                self?.onSelect?(value)
            }
        }
        button.menu = UIMenu(children: actions)
        button.configuration?.title = model.valueText
    }
}
