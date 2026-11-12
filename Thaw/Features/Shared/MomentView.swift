import UIKit

/// Full-screen Cubi moment: a face and one line, shown briefly after Add and Skip. Tap to skip.
final class MomentView: UIView {
    private var completion: (() -> Void)?
    private var finished = false

    init(mood: CubiMood, line: String) {
        super.init(frame: .zero)
        backgroundColor = Theme.background

        let cubi = CubiView(mood: mood, size: .feature)
        cubi.spokenLine = line
        let label = UILabel()
        label.text = line
        label.font = ThawFont.display(26)
        label.adjustsFontForContentSizeCategory = true
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
        accessibilityViewIsModal = true
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(skip)))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc private func skip() { finish() }

    override func accessibilityPerformEscape() -> Bool {
        finish()
        return true
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        let done = completion
        completion = nil
        done?()
        removeFromSuperview()
    }

    /// Covers `host`, holds for `duration` (longer with VoiceOver), then calls `completion` once.
    static func present(on host: UIView, mood: CubiMood, line: String, duration: TimeInterval = 1.2,
                        completion: @escaping () -> Void) {
        let moment = MomentView(mood: mood, line: line)
        moment.completion = completion
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
        let hold = UIAccessibility.isVoiceOverRunning ? max(duration, 3) : duration
        DispatchQueue.main.asyncAfter(deadline: .now() + hold) { [weak moment] in
            moment?.finish()
        }
    }
}
