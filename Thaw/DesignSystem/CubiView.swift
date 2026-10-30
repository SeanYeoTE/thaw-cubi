import UIKit

enum CubiMood: CaseIterable {
    case frozen, thawing, thawed, proud, snoozing

    var line: String {
        switch self {
        case .frozen: "Brr. See you on payday."
        case .thawing: "Still on your mind?"
        case .thawed: "I've thawed. Your call."
        case .proud: "That money stays with you."
        case .snoozing: "Back in the freezer till next payday."
        }
    }

    static func thawingLine(days: Int) -> String {
        "Still on your mind? Payday's in \(days) \(days == 1 ? "day" : "days")."
    }

    /// `amount` is the formatted figure, with or without the "S$" prefix.
    static func proudLine(amount: String) -> String {
        "\(amount.hasPrefix("S$") ? amount : "S$" + amount) stays with you."
    }

    func thawingLine(days: Int) -> String { Self.thawingLine(days: days) }
    func proudLine(amount: String) -> String { Self.proudLine(amount: amount) }
}

/// Cubi: fixed body and eye line; only the face and one prop vary per mood.
/// Drawn at the design's native 160x170 viewBox and scaled, so it stays crisp.
final class CubiView: UIView {
    private static let viewBox = CGSize(width: 160, height: 170)

    private let art = CALayer()
    private let backLayer = CALayer()
    private let bodyLayer = CAShapeLayer()
    private let highlightLayer = CAShapeLayer()
    private let faceLayer = CALayer()
    private let propLayer = CALayer()

    private(set) var mood: CubiMood
    private(set) var onFrost: Bool
    private let size: CGFloat
    private var playedInitialMotion = false

    var spokenLine: String? {
        didSet { updateAccessibility() }
    }

    /// `onFrost` draws a white body so Cubi stays distinct on Frost (`cubeFill`) backgrounds.
    init(mood: CubiMood, size: CGFloat = 64, onFrost: Bool = false) {
        self.mood = mood
        self.onFrost = onFrost
        self.size = size
        super.init(frame: CGRect(x: 0, y: 0, width: size, height: size * Self.viewBox.height / Self.viewBox.width))
        backgroundColor = .clear
        isOpaque = false
        isAccessibilityElement = true
        accessibilityTraits = .image
        buildBody()
        art.addSublayer(backLayer)
        art.addSublayer(bodyLayer)
        art.addSublayer(highlightLayer)
        art.addSublayer(faceLayer)
        art.addSublayer(propLayer)
        layer.addSublayer(art)
        applyMood(mood)
        updateAccessibility()
        NotificationCenter.default.addObserver(
            self, selector: #selector(reduceMotionChanged),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var intrinsicContentSize: CGSize {
        CGSize(width: size, height: size * Self.viewBox.height / Self.viewBox.width)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let scale = bounds.width / Self.viewBox.width
        art.anchorPoint = .zero
        art.bounds = CGRect(origin: .zero, size: Self.viewBox)
        art.position = .zero
        art.transform = CATransform3DMakeScale(scale, scale, 1)
        let screenScale = window?.screen.scale ?? traitCollection.displayScale
        for sub in allShapeLayers(in: art) { sub.contentsScale = max(screenScale, 1) }
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
        buildBody()
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
        if animated, !UIAccessibility.isReduceMotionEnabled {
            playMotion(for: mood)
        }
    }

    // MARK: Accessibility

    private func updateAccessibility() {
        accessibilityLabel = "Cubi: \(spokenLine ?? mood.line)"
    }

    @objc private func reduceMotionChanged() {
        art.removeAllAnimations()
        propLayer.removeAllAnimations()
    }

    // MARK: Drawing

    private func allShapeLayers(in root: CALayer) -> [CALayer] {
        var result: [CALayer] = [root]
        for sub in root.sublayers ?? [] { result += allShapeLayers(in: sub) }
        return result
    }

    private static func bodyPath() -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 48, y: 24))
        path.addLine(to: CGPoint(x: 114, y: 24))
        path.addLine(to: CGPoint(x: 122, y: 36))
        path.addLine(to: CGPoint(x: 140, y: 42))
        path.addLine(to: CGPoint(x: 140, y: 116))
        path.addQuadCurve(to: CGPoint(x: 112, y: 144), controlPoint: CGPoint(x: 140, y: 144))
        path.addLine(to: CGPoint(x: 48, y: 144))
        path.addQuadCurve(to: CGPoint(x: 20, y: 116), controlPoint: CGPoint(x: 20, y: 144))
        path.addLine(to: CGPoint(x: 20, y: 52))
        path.addQuadCurve(to: CGPoint(x: 48, y: 24), controlPoint: CGPoint(x: 20, y: 24))
        path.close()
        return path
    }

    private func buildBody() {
        bodyLayer.path = Self.bodyPath().cgPath
        bodyLayer.fillColor = (onFrost ? UIColor.white : Theme.cubeFill).cgColor
        bodyLayer.strokeColor = Theme.cubeOutline.cgColor
        bodyLayer.lineWidth = size < 64 ? 9 : 6
        bodyLayer.lineJoin = .round

        let highlight = UIBezierPath()
        highlight.move(to: CGPoint(x: 40, y: 54))
        highlight.addQuadCurve(to: CGPoint(x: 52, y: 42), controlPoint: CGPoint(x: 40, y: 42))
        highlight.addLine(to: CGPoint(x: 68, y: 42))
        highlightLayer.path = highlight.cgPath
        highlightLayer.strokeColor = (onFrost ? Theme.cubeFill : UIColor.white).cgColor
        highlightLayer.fillColor = nil
        highlightLayer.lineWidth = 8
        highlightLayer.lineCap = .round
    }

    private func stroke(_ path: UIBezierPath, color: UIColor, width: CGFloat, join: CAShapeLayerLineJoin = .round) -> CAShapeLayer {
        let shape = CAShapeLayer()
        shape.path = path.cgPath
        shape.strokeColor = color.cgColor
        shape.fillColor = nil
        shape.lineWidth = width
        shape.lineCap = .round
        shape.lineJoin = join
        return shape
    }

    private func fill(_ path: UIBezierPath, color: UIColor) -> CAShapeLayer {
        let shape = CAShapeLayer()
        shape.path = path.cgPath
        shape.fillColor = color.cgColor
        return shape
    }

    private func dot(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ color: UIColor) -> CAShapeLayer {
        fill(UIBezierPath(ovalIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), color: color)
    }

    private func line(_ points: [(CGFloat, CGFloat)]) -> UIBezierPath {
        let path = UIBezierPath()
        for (index, point) in points.enumerated() {
            let p = CGPoint(x: point.0, y: point.1)
            if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        return path
    }

    private func sparkle(_ cx: CGFloat, _ cy: CGFloat, _ arm: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: cx, y: cy - arm)); path.addLine(to: CGPoint(x: cx, y: cy + arm))
        path.move(to: CGPoint(x: cx - arm, y: cy)); path.addLine(to: CGPoint(x: cx + arm, y: cy))
        return path
    }

    private func setSublayers(_ parent: CALayer, _ layers: [CALayer]) {
        parent.sublayers?.forEach { $0.removeFromSuperlayer() }
        layers.forEach { parent.addSublayer($0) }
    }

    private func applyMood(_ mood: CubiMood) {
        var back: [CALayer] = []
        var face: [CALayer] = []
        var prop: [CALayer] = []
        let ink = Theme.ink

        switch mood {
        case .frozen:
            face.append(stroke(line([(53, 86), (71, 86)]), color: ink, width: 7))
            face.append(stroke(line([(89, 86), (107, 86)]), color: ink, width: 7))
            face.append(stroke(line([(62, 112), (68, 107), (74, 112), (80, 107), (86, 112), (92, 107), (98, 112)]), color: ink, width: 5))
            let sparkles = UIBezierPath()
            sparkles.append(sparkle(150, 15, 7))
            sparkles.append(sparkle(8, 131, 5))
            prop.append(stroke(sparkles, color: Theme.cubeStroke, width: 4))
        case .thawing:
            face.append(dot(68, 86, 8, ink))
            face.append(dot(104, 86, 8, ink))
            face.append(stroke(line([(72, 112), (90, 112)]), color: ink, width: 6))
            let drip = UIBezierPath()
            drip.move(to: CGPoint(x: 34, y: 146))
            drip.addQuadCurve(to: CGPoint(x: 34, y: 160), controlPoint: CGPoint(x: 28, y: 156))
            drip.addQuadCurve(to: CGPoint(x: 34, y: 146), controlPoint: CGPoint(x: 40, y: 156))
            drip.close()
            prop.append(fill(drip, color: Theme.cubeStroke))
        case .thawed:
            back.append(dot(80, 86, 76, Theme.glow))
            back.append(fill(UIBezierPath(ovalIn: CGRect(x: 16, y: 143, width: 128, height: 18)), color: Theme.puddle))
            face.append(dot(62, 86, 10, ink))
            face.append(dot(98, 86, 10, ink))
            face.append(dot(65, 83, 3, .white))
            face.append(dot(101, 83, 3, .white))
            face.append(dot(80, 114, 6, ink))
        case .proud:
            let eyes = UIBezierPath()
            eyes.append(line([(53, 90), (62, 81), (71, 90)]))
            eyes.append(line([(89, 90), (98, 81), (107, 90)]))
            face.append(stroke(eyes, color: ink, width: 6))
            let smile = UIBezierPath()
            smile.move(to: CGPoint(x: 60, y: 106))
            smile.addQuadCurve(to: CGPoint(x: 100, y: 106), controlPoint: CGPoint(x: 80, y: 128))
            face.append(stroke(smile, color: ink, width: 6))
            let star = UIBezierPath()
            star.move(to: CGPoint(x: 14, y: 4)); star.addLine(to: CGPoint(x: 18, y: 14))
            star.addLine(to: CGPoint(x: 28, y: 18)); star.addLine(to: CGPoint(x: 18, y: 22))
            star.addLine(to: CGPoint(x: 14, y: 32)); star.addLine(to: CGPoint(x: 10, y: 22))
            star.addLine(to: CGPoint(x: 0, y: 18)); star.addLine(to: CGPoint(x: 10, y: 14))
            star.close()
            prop.append(fill(star, color: Theme.ember))
        case .snoozing:
            let eyes = UIBezierPath()
            for x: CGFloat in [53, 89] {
                eyes.move(to: CGPoint(x: x, y: 84))
                eyes.addQuadCurve(to: CGPoint(x: x + 18, y: 84), controlPoint: CGPoint(x: x + 9, y: 92))
            }
            face.append(stroke(eyes, color: ink, width: 6))
            face.append(dot(80, 112, 5, ink))
            prop.append(stroke(line([(132, 14), (142, 14), (132, 26), (142, 26)]), color: Theme.accent, width: 3.5))
            prop.append(stroke(line([(144, 2), (151, 2), (144, 11), (151, 11)]), color: Theme.accent, width: 2.5))
        }

        setSublayers(backLayer, back)
        setSublayers(faceLayer, face)
        setSublayers(propLayer, prop)
        setNeedsLayout()
    }

    // MARK: Motion

    private func playMotion(for mood: CubiMood) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        switch mood {
        case .frozen: // shiver
            let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
            shake.values = [0, -3, 3, -2, 2, 0]
            shake.duration = 0.45
            faceLayer.add(shake, forKey: "motion")
            bodyLayer.add(shake, forKey: "motion")
            highlightLayer.add(shake, forKey: "motion")
        case .thawing: // drip
            let drop = CABasicAnimation(keyPath: "transform.translation.y")
            drop.fromValue = -6
            drop.toValue = 8
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 1
            fade.toValue = 0.2
            let group = CAAnimationGroup()
            group.animations = [drop, fade]
            group.duration = 0.5
            propLayer.add(group, forKey: "motion")
        case .thawed: // bounce
            let bounce = CAKeyframeAnimation(keyPath: "transform.translation.y")
            bounce.values = [0, -8, 0, -3, 0]
            bounce.duration = 0.5
            bounce.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeOut), count: 4)
            for target in [bodyLayer, highlightLayer, faceLayer] { target.add(bounce, forKey: "motion") }
        case .proud: // sparkle
            let pop = CAKeyframeAnimation(keyPath: "transform.scale")
            pop.values = [0.2, 1.3, 1]
            pop.duration = 0.5
            propLayer.add(pop, forKey: "motion")
        case .snoozing: // float
            let rise = CABasicAnimation(keyPath: "transform.translation.y")
            rise.fromValue = 8
            rise.toValue = 0
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0
            fade.toValue = 1
            let group = CAAnimationGroup()
            group.animations = [rise, fade]
            group.duration = 0.5
            propLayer.add(group, forKey: "motion")
        }
    }
}
