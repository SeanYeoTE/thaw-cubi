import UIKit

/// Light list section header: title on the left, optional detail on the right ("This payday" / "S$320").
/// One line at standard sizes, wrapping and stacking at accessibility sizes. Has no insets of its own, so it
/// can be pinned straight into a cell's content view; call `configure` when the cell is reused.
final class SectionHeaderView: UIView {
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let row = AdaptiveStackView()

    init(title: String, detail: String? = nil) {
        super.init(frame: .zero)
        for label in [titleLabel, detailLabel] {
            label.font = ThawFont.body(13, weight: .semibold)
            label.textColor = Theme.inkSecondary
            label.adjustsFontForContentSizeCategory = true
        }
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        detailLabel.textAlignment = .right
        detailLabel.setContentHuggingPriority(.required, for: .horizontal)
        detailLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        row.addArrangedSubview(titleLabel)
        row.addArrangedSubview(detailLabel)
        row.compactAlignment = .firstBaseline
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        isAccessibilityElement = true
        accessibilityTraits = .header
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: SectionHeaderView, _) in
            self.updateLineCount()
        }
        updateLineCount()
        configure(title: title, detail: detail)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(title: String, detail: String?) {
        titleLabel.text = title
        detailLabel.text = detail
        detailLabel.isHidden = detail?.isEmpty ?? true
        accessibilityLabel = [title, detail].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }

    private func updateLineCount() {
        let large = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        titleLabel.numberOfLines = large ? 0 : 1
        detailLabel.numberOfLines = large ? 0 : 1
        detailLabel.textAlignment = large ? .natural : .right
    }
}
