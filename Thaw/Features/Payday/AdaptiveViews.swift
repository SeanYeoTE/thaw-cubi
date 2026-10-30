import UIKit

/// Horizontal stack that turns vertical at accessibility text sizes (D5).
final class AdaptiveStackView: UIStackView {
    var compactAlignment: UIStackView.Alignment = .center {
        didSet { updateAxis() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    convenience init(arrangedSubviews: [UIView]) {
        self.init(frame: .zero)
        arrangedSubviews.forEach(addArrangedSubview)
    }

    private func setUp() {
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: AdaptiveStackView, _) in
            self.updateAxis()
        }
        updateAxis()
    }

    private func updateAxis() {
        let large = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        axis = large ? .vertical : .horizontal
        alignment = large ? .leading : compactAlignment
    }
}

/// Cubi beside a line of speech; stacks at accessibility sizes.
final class CubiHeaderView: UIView {
    init(mood: CubiMood, line: String, spoken: String, size: CGFloat = 56) {
        super.init(frame: .zero)
        let cubi = CubiView(mood: mood, size: size)
        cubi.setContentHuggingPriority(.required, for: .horizontal)
        cubi.setContentCompressionResistancePriority(.required, for: .horizontal)
        let label = UILabel()
        label.text = line
        label.font = ThawFont.body(15)
        label.textColor = Theme.inkSecondary
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.isAccessibilityElement = false
        cubi.spokenLine = spoken

        let row = AdaptiveStackView(arrangedSubviews: [cubi, label])
        row.compactAlignment = .center
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}
