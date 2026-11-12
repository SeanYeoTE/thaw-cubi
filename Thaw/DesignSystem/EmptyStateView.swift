import UIKit

/// Centred empty state: Cubi, one short line and an optional primary button.
final class EmptyStateView: UIView {
    var onAction: (() -> Void)?

    init(mood: CubiMood, line: String, actionTitle: String?) {
        super.init(frame: .zero)
        let cubi = CubiView(mood: mood, size: 96)
        // The line is spoken through Cubi, so VoiceOver reads it once.
        cubi.spokenLine = line

        let label = UILabel()
        label.text = line
        label.font = ThawFont.body(15)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = Theme.inkSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.isAccessibilityElement = false

        let stack = UIStackView(arrangedSubviews: [cubi, label])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = Theme.Spacing.gap
        stack.setCustomSpacing(Theme.Spacing.gap + 8, after: label)

        if let actionTitle {
            let button = PillButton(title: actionTitle, style: .primary)
            button.addAction(UIAction { [weak self] _ in self?.onAction?() }, for: .touchUpInside)
            stack.addArrangedSubview(button)
        }

        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}
