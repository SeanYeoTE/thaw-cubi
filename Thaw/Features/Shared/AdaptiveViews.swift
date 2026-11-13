import UIKit

/// Horizontal stack that turns vertical at accessibility text sizes (D5).
final class AdaptiveStackView: UIStackView {
    var compactAlignment: UIStackView.Alignment = .center {
        didSet { updateAxis() }
    }

    /// Alignment once stacked at accessibility sizes. `.fill` gives each view the full width, which text fields need.
    var largeAlignment: UIStackView.Alignment = .leading {
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
        alignment = large ? largeAlignment : compactAlignment
    }
}
