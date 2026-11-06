import UIKit

/// Tappable cooling row: the shared `WantRowView` inside a control, with the context menu attached by the caller.
final class WantCardView: UIControl {
    /// Shown on long-press (Edit, Delete).
    var contextMenu: UIMenu?

    init(model: HomeCardViewModel) {
        super.init(frame: .zero)
        let row = WantRowView(model: WantRowModel(
            title: model.name, priceText: model.priceText, status: model.statusText,
            statusTone: .neutral, trailing: model.trailingText,
            progress: model.progress, progressTone: model.isTimer ? .timer : .accent,
            accessibilityLabel: "\(model.name), \(model.priceText)",
            accessibilityValue: "\(model.statusText), \(model.trailingText)"))
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        isAccessibilityElement = true
        accessibilityLabel = "\(model.name), \(model.priceText)"
        accessibilityValue = "\(model.statusText), \(model.trailingText)"
        accessibilityTraits = .button
        isContextMenuInteractionEnabled = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        guard let contextMenu else { return nil }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in contextMenu }
    }
}
