import UIKit

/// Look shared by the Cooling and Stats want lists, so swipe actions match on both screens.
enum WantListStyle {
    static let rowGap: CGFloat = 14
    static let maxContentWidth: CGFloat = 700

    /// Section insets for a list section: content capped at `maxContentWidth` and centred, with at least
    /// `Theme.Spacing.screen` plus the safe area on each side. Use with `contentInsetsReference = .none`.
    static func contentInsets(
        environment: NSCollectionLayoutEnvironment, safeArea: UIEdgeInsets, top: CGFloat = 0, bottom: CGFloat = 0
    ) -> NSDirectionalEdgeInsets {
        let available = environment.container.contentSize.width - safeArea.left - safeArea.right
        let side = max(Theme.Spacing.screen, (available - maxContentWidth) / 2)
        return NSDirectionalEdgeInsets(top: top, leading: safeArea.left + side, bottom: bottom, trailing: safeArea.right + side)
    }

    /// Rows sit flush in their cells and the gap comes from `interGroupSpacing`, so the swipe buttons are exactly card height.
    static func applyRowSpacing(to section: NSCollectionLayoutSection) {
        section.interGroupSpacing = rowGap
    }

    /// Swipe buttons are icon-only, so cells also expose Edit and Delete as named VoiceOver actions.
    static func accessibilityActions(onEdit: @escaping () -> Void, onDelete: @escaping () -> Void) -> [UIAccessibilityCustomAction] {
        [
            UIAccessibilityCustomAction(name: "Edit") { _ in onEdit(); return true },
            UIAccessibilityCustomAction(name: "Delete") { _ in onDelete(); return true },
        ]
    }

    static func swipeActions(onEdit: @escaping () -> Void, onDelete: @escaping () -> Void) -> UISwipeActionsConfiguration {
        let delete = UIContextualAction(style: .destructive, title: nil) { _, _, done in
            // The row stays until the user confirms, so the swipe reports "not performed".
            done(false)
            onDelete()
        }
        delete.image = UIImage(systemName: "trash")
        let edit = UIContextualAction(style: .normal, title: nil) { _, _, done in
            done(true)
            onEdit()
        }
        edit.image = UIImage(systemName: "pencil")
        edit.backgroundColor = Theme.accent
        let configuration = UISwipeActionsConfiguration(actions: [delete, edit])
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }
}
