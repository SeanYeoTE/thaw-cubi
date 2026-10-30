import UIKit

/// A settings row with a stepper; the stepper moves under the value at accessibility sizes.
final class StepperSettingRow: UIView {
    private let row: SettingsRowView
    private let stepper = UIStepper()
    private let container = UIStackView()
    private let format: (Double) -> String
    var onChange: (() -> Void)?

    var value: Double { stepper.value }

    init(title: String, subtitle: String? = nil, range: ClosedRange<Double>, step: Double, value: Double,
         format: @escaping (Double) -> String) {
        self.format = format
        row = SettingsRowView(title: title, subtitle: subtitle, value: format(value))
        super.init(frame: .zero)
        stepper.minimumValue = range.lowerBound
        stepper.maximumValue = range.upperBound
        stepper.stepValue = step
        stepper.value = value
        stepper.accessibilityLabel = title
        stepper.setContentHuggingPriority(.required, for: .horizontal)
        stepper.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.row.value = self.format(self.stepper.value)
            self.onChange?()
        }, for: .valueChanged)

        container.addArrangedSubview(row)
        container.addArrangedSubview(stepper)
        container.spacing = 12
        container.translatesAutoresizingMaskIntoConstraints = false
        addSubview(container)
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor),
            container.topAnchor.constraint(equalTo: topAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        updateAxis()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: StepperSettingRow, _) in
            self.updateAxis()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func updateAxis() {
        let large = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        container.axis = large ? .vertical : .horizontal
        container.alignment = large ? .leading : .center
    }
}
