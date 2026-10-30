import UIKit

/// Full-screen Cubi moment: a face and one line, shown briefly after Add and Skip.
final class MomentView: UIView {
    init(mood: CubiMood, line: String) {
        super.init(frame: .zero)
        backgroundColor = Theme.background

        let cubi = CubiView(mood: mood, size: 120)
        cubi.spokenLine = line
        let label = UILabel()
        label.text = line
        label.font = ThawFont.display(26)
        label.textColor = Theme.ink
        label.textAlignment = .center
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.isAccessibilityElement = false

        let stack = UIStackView(arrangedSubviews: [cubi, label])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Theme.Spacing.screen),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Theme.Spacing.screen),
        ])
        alpha = 0
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Covers `host`, holds for `duration`, then calls `completion`.
    static func present(on host: UIView, mood: CubiMood, line: String, duration: TimeInterval = 1.2,
                        completion: @escaping () -> Void) {
        let moment = MomentView(mood: mood, line: line)
        moment.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(moment)
        NSLayoutConstraint.activate([
            moment.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            moment.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            moment.topAnchor.constraint(equalTo: host.topAnchor),
            moment.bottomAnchor.constraint(equalTo: host.bottomAnchor),
        ])
        UIAccessibility.post(notification: .screenChanged, argument: moment.subviews.first)
        UIView.animate(withDuration: 0.2) { moment.alpha = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            completion()
            moment.removeFromSuperview()
        }
    }
}
