import UIKit

/// Wraps a task screen in a navigation controller presented as a page sheet that swipe-down cannot discard.
enum ReviewSheet {
    static func wrap(_ root: UIViewController) -> UINavigationController {
        let nav = UINavigationController(rootViewController: root)
        nav.isModalInPresentation = true
        return nav
    }
}
