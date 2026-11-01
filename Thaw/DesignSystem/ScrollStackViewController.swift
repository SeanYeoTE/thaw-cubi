import UIKit

/// Base screen: a vertical stack inside a scroll view, on the Thaw background.
class ScrollStackViewController: UIViewController {
    let stack = UIStackView()
    let scrollView = UIScrollView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = Theme.Spacing.gap
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(stack)
        let guide = view.safeAreaLayoutGuide
        // Hidden keyboard keeps the guide at the view's bottom edge, as before.
        view.keyboardLayoutGuide.usesBottomSafeArea = false
        let inset = Theme.Spacing.screen
        let leading = stack.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: inset)
        let trailing = stack.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -inset)
        leading.priority = .defaultHigh
        trailing.priority = .defaultHigh
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: guide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            leading,
            trailing,
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: guide.leadingAnchor, constant: inset),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: guide.trailingAnchor, constant: -inset),
            stack.widthAnchor.constraint(lessThanOrEqualTo: view.readableContentGuide.widthAnchor),
            stack.centerXAnchor.constraint(equalTo: guide.centerXAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
        ])
        buildContent()
    }

    /// Subclasses add their views to `stack`.
    func buildContent() {}

    /// Scrolls so `target` (any descendant of the scroll view) is visible above the keyboard.
    func scrollToVisible(_ target: UIView) {
        view.layoutIfNeeded()
        let rect = target.convert(target.bounds, to: scrollView).insetBy(dx: 0, dy: -12)
        scrollView.scrollRectToVisible(rect, animated: true)
    }

    func clearContent() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
    }

    func makeLabel(_ text: String, font: UIFont, color: UIColor = Theme.ink) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = color
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        return label
    }
}
