import UIKit

/// Look shared by the Cooling and Stats want lists, so swipe actions match on both screens.
enum WantListStyle {
    static let rowGap: CGFloat = 14

    /// Rows sit flush in their cells and the gap comes from `interGroupSpacing`, so the swipe buttons are exactly card height.
    static func applyRowSpacing(to section: NSCollectionLayoutSection) {
        section.interGroupSpacing = rowGap
    }

    static func swipeActions(onEdit: @escaping () -> Void, onDelete: @escaping () -> Void) -> UISwipeActionsConfiguration {
        let delete = UIContextualAction(style: .destructive, title: "Delete") { _, _, done in
            // The row stays until the user confirms, so the swipe reports "not performed".
            done(false)
            onDelete()
        }
        delete.image = UIImage(systemName: "trash")
        let edit = UIContextualAction(style: .normal, title: "Edit") { _, _, done in
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
