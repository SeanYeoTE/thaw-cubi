import UIKit

/// The sizes Cubi appears at, so screens pick a role instead of a number.
enum CubiSize: CGFloat {
    /// Beside a line of speech.
    case inline = 56
    /// Leading a hero card, such as Payday and Stats.
    case card = 88
    /// Centred on his own: empty states and moments.
    case feature = 120
}

/// Cubi: fixed body and eye line; only the face and one prop vary per mood.
/// Artwork lives in `CubiArtwork` and motion in `CubiMotion`; this view handles layout and accessibility.
final class CubiView: UIView {
    private let art = CALayer()
    private let backLayer = CALayer()
    private let bodyLayer = CAShapeLayer()
    private let highlightLayer = CAShapeLayer()
    private let faceLayer = CALayer()
    private let propLayer = CALayer()

    private(set) var mood: CubiMood
    private(set) var onFrost: Bool
    private let width: CGFloat
    private var playedInitialMotion = false

    var spokenLine: String? {
        didSet { updateAccessibility() }
    }

    convenience init(mood: CubiMood, size: CubiSize, onFrost: Bool = false) {
        self.init(mood: mood, points: size.rawValue, onFrost: onFrost)
    }

    init(mood: CubiMood, points: CGFloat = 64, onFrost: Bool = false) {
        self.mood = mood
        self.onFrost = onFrost
        self.width = points
        let viewBox = CubiArtwork.viewBox
        super.init(frame: CGRect(x: 0, y: 0, width: points, height: points * viewBox.height / viewBox.width))
        backgroundColor = .clear
        isOpaque = false
        isAccessibilityElement = true
        accessibilityTraits = .image
        // Cubi is artwork: Smart Invert would turn the ice cube dark and the face light.
        accessibilityIgnoresInvertColors = true
        styleBody()
        [backLayer, bodyLayer, highlightLayer, faceLayer, propLayer].forEach(art.addSublayer)
        layer.addSublayer(art)
        applyMood(mood)
        updateAccessibility()
        NotificationCenter.default.addObserver(
            self, selector: #selector(reduceMotionChanged),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var intrinsicContentSize: CGSize {
        let viewBox = CubiArtwork.viewBox
        return CGSize(width: width, height: width * viewBox.height / viewBox.width)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let scale = bounds.width / CubiArtwork.viewBox.width
        art.anchorPoint = .zero
        art.bounds = CGRect(origin: .zero, size: CubiArtwork.viewBox)
        art.position = .zero
        art.transform = CATransform3DMakeScale(scale, scale, 1)
        let screenScale = max(window?.screen.scale ?? traitCollection.displayScale, 1)
        applyContentsScale(screenScale, in: art)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil, !playedInitialMotion else { return }
        playedInitialMotion = true
        playMotion(for: mood)
    }

    func setOnFrost(_ onFrost: Bool) {
        guard onFrost != self.onFrost else { return }
        self.onFrost = onFrost
        styleBody()
    }

    func setMood(_ mood: CubiMood, animated: Bool) {
        guard mood != self.mood else { return }
        self.mood = mood
        if animated {
            let fade = CATransition()
            fade.type = .fade
            fade.duration = 0.25
            art.add(fade, forKey: "fade")
        }
        applyMood(mood)
        updateAccessibility()
        if animated { playMotion(for: mood) }
    }

    // MARK: Accessibility

    private func updateAccessibility() {
        accessibilityLabel = "Cubi: \(spokenLine ?? mood.accessibilityName)"
    }

    @objc private func reduceMotionChanged() {
        art.removeAllAnimations()
        [bodyLayer, highlightLayer, faceLayer, propLayer].forEach { $0.removeAllAnimations() }
    }

    // MARK: Drawing

    private func applyContentsScale(_ scale: CGFloat, in root: CALayer) {
        root.contentsScale = scale
        root.sublayers?.forEach { applyContentsScale(scale, in: $0) }
    }

    private func styleBody() {
        CubiArtwork.style(body: bodyLayer, highlight: highlightLayer, onFrost: onFrost, small: width < 64)
    }

    private func applyMood(_ mood: CubiMood) {
        let parts = CubiArtwork.face(for: mood)
        replace(backLayer, with: parts.back)
        replace(faceLayer, with: parts.face)
        replace(propLayer, with: parts.prop)
        setNeedsLayout()
    }

    private func replace(_ parent: CALayer, with layers: [CALayer]) {
        parent.sublayers?.forEach { $0.removeFromSuperlayer() }
        layers.forEach(parent.addSublayer)
    }

    // MARK: Motion

    private func playMotion(for mood: CubiMood) {
        for step in CubiMotion.steps(for: mood) {
            switch step.part {
            case .body: [bodyLayer, highlightLayer, faceLayer].forEach { $0.add(step.animation, forKey: "motion") }
            case .prop: propLayer.add(step.animation, forKey: "motion")
            }
        }
    }
}
