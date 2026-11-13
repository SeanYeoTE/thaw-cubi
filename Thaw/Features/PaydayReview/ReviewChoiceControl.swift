import UIKit

/// Keep · Wait · Let go. Each option is its own button so it can carry an identifier and a spoken label.
final class ReviewChoiceControl: UIStackView {
    private(set) var choice: ReviewChoice
    var onChange: ((ReviewChoice) -> Void)?
    private var buttons: [ReviewChoice: UIButton] = [:]

    init(choice: ReviewChoice, labels: [String]) {
        self.choice = choice
        super.init(frame: .zero)
        distribution = .fillEqually
        spacing = 8
        updateAxis()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: ReviewChoiceControl, _) in
            self.updateAxis()
        }
        let identifiers: [ReviewChoice: String] = [.keep: "review.keep", .wait: "review.wait", .letGo: "review.letGo"]
        for option in ReviewChoice.allCases {
            let button = UIButton(configuration: .plain())
            button.configurationUpdateHandler = { button in
                var config = UIButton.Configuration.filled()
                config.cornerStyle = .capsule
                config.title = option.title
                config.titleLineBreakMode = .byWordWrapping
                config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 8, bottom: 10, trailing: 8)
                config.imagePadding = 4
                if button.isSelected {
                    config.baseBackgroundColor = Theme.accent
                    config.baseForegroundColor = Theme.onAccent
                    config.image = UIImage(systemName: "checkmark")
                } else {
                    config.baseBackgroundColor = Theme.surface
                    config.baseForegroundColor = Theme.ink
                    config.background.strokeColor = Theme.controlBorder
                    config.background.strokeWidth = 1
                }
                config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                    var updated = attributes
                    updated.font = ThawFont.body(15, weight: .semibold)
                    return updated
                }
                button.configuration = config
            }
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            button.titleLabel?.numberOfLines = 0
            button.accessibilityIdentifier = identifiers[option]
            button.accessibilityLabel = option.rawValue < labels.count ? labels[option.rawValue] : option.title
            button.addAction(UIAction { [weak self] _ in self?.select(option) }, for: .touchUpInside)
            buttons[option] = button
            addArrangedSubview(button)
        }
        refresh()
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Three equal segments are about 100 pt wide on a phone, so "✓ Let go" runs out of room before the
    /// accessibility sizes. Stack the options from XXL up so no title is clipped.
    private func updateAxis() {
        axis = traitCollection.preferredContentSizeCategory >= .extraExtraLarge ? .vertical : .horizontal
    }

    private func select(_ option: ReviewChoice) {
        guard option != choice else { return }
        choice = option
        refresh()
        onChange?(option)
    }

    private func refresh() {
        for (option, button) in buttons {
            button.isSelected = option == choice
            button.accessibilityTraits = option == choice ? [.button, .selected] : .button
        }
    }
}
