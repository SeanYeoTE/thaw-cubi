import UIKit

/// Cubi's drawing, in the design's native 160x170 viewBox. Pure functions: mood in, layers out.
enum CubiArtwork {
    static let viewBox = CGSize(width: 160, height: 170)

    struct Face {
        var back: [CALayer] = []
        var face: [CALayer] = []
        var prop: [CALayer] = []
    }

    static func bodyPath() -> UIBezierPath {
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

    /// `onFrost` draws a white body so Cubi stays distinct on Frost (`cubeFill`) backgrounds.
    static func style(body: CAShapeLayer, highlight: CAShapeLayer, onFrost: Bool, small: Bool) {
        body.path = bodyPath().cgPath
        body.fillColor = (onFrost ? UIColor.white : Theme.cubeFill).cgColor
        body.strokeColor = Theme.cubeOutline.cgColor
        body.lineWidth = small ? 9 : 6
        body.lineJoin = .round

        let path = UIBezierPath()
        path.move(to: CGPoint(x: 40, y: 54))
        path.addQuadCurve(to: CGPoint(x: 52, y: 42), controlPoint: CGPoint(x: 40, y: 42))
        path.addLine(to: CGPoint(x: 68, y: 42))
        highlight.path = path.cgPath
        highlight.strokeColor = (onFrost ? Theme.cubeFill : UIColor.white).cgColor
        highlight.fillColor = nil
        highlight.lineWidth = 8
        highlight.lineCap = .round
    }

    static func face(for mood: CubiMood) -> Face {
        var result = Face()
        let ink = Theme.cubiInk

        switch mood {
        case .frozen:
            result.face = [
                stroke(line([(53, 86), (71, 86)]), ink, 7),
                stroke(line([(89, 86), (107, 86)]), ink, 7),
                stroke(line([(62, 112), (68, 107), (74, 112), (80, 107), (86, 112), (92, 107), (98, 112)]), ink, 5),
            ]
            let sparkles = UIBezierPath()
            sparkles.append(sparkle(150, 15, 7))
            sparkles.append(sparkle(8, 131, 5))
            result.prop = [stroke(sparkles, Theme.cubeStroke, 4)]
        case .thawing:
            result.face = [
                dot(68, 86, 8, ink), dot(104, 86, 8, ink),
                stroke(line([(72, 112), (90, 112)]), ink, 6),
            ]
            let drip = UIBezierPath()
            drip.move(to: CGPoint(x: 34, y: 146))
            drip.addQuadCurve(to: CGPoint(x: 34, y: 160), controlPoint: CGPoint(x: 28, y: 156))
            drip.addQuadCurve(to: CGPoint(x: 34, y: 146), controlPoint: CGPoint(x: 40, y: 156))
            drip.close()
            result.prop = [fill(drip, Theme.cubeStroke)]
        case .thawed:
            result.back = [
                dot(80, 86, 76, Theme.glow),
                fill(UIBezierPath(ovalIn: CGRect(x: 16, y: 143, width: 128, height: 18)), Theme.puddle),
            ]
            result.face = [
                dot(62, 86, 10, ink), dot(98, 86, 10, ink),
                dot(65, 83, 3, .white), dot(101, 83, 3, .white),
                dot(80, 114, 6, ink),
            ]
        case .proud:
            let eyes = UIBezierPath()
            eyes.append(line([(53, 90), (62, 81), (71, 90)]))
            eyes.append(line([(89, 90), (98, 81), (107, 90)]))
            let smile = UIBezierPath()
            smile.move(to: CGPoint(x: 60, y: 106))
            smile.addQuadCurve(to: CGPoint(x: 100, y: 106), controlPoint: CGPoint(x: 80, y: 128))
            result.face = [stroke(eyes, ink, 6), stroke(smile, ink, 6)]
            let star = UIBezierPath()
            star.move(to: CGPoint(x: 14, y: 4)); star.addLine(to: CGPoint(x: 18, y: 14))
            star.addLine(to: CGPoint(x: 28, y: 18)); star.addLine(to: CGPoint(x: 18, y: 22))
            star.addLine(to: CGPoint(x: 14, y: 32)); star.addLine(to: CGPoint(x: 10, y: 22))
            star.addLine(to: CGPoint(x: 0, y: 18)); star.addLine(to: CGPoint(x: 10, y: 14))
            star.close()
            result.prop = [fill(star, Theme.ember)]
        case .snoozing:
            let eyes = UIBezierPath()
            for x: CGFloat in [53, 89] {
                eyes.move(to: CGPoint(x: x, y: 84))
                eyes.addQuadCurve(to: CGPoint(x: x + 18, y: 84), controlPoint: CGPoint(x: x + 9, y: 92))
            }
            result.face = [stroke(eyes, ink, 6), dot(80, 112, 5, ink)]
            result.prop = [
                stroke(line([(132, 14), (142, 14), (132, 26), (142, 26)]), Theme.cubiAccent, 3.5),
                stroke(line([(144, 2), (151, 2), (144, 11), (151, 11)]), Theme.cubiAccent, 2.5),
            ]
        }
        return result
    }

    // MARK: Shape builders

    private static func stroke(_ path: UIBezierPath, _ color: UIColor, _ width: CGFloat) -> CAShapeLayer {
        let shape = CAShapeLayer()
        shape.path = path.cgPath
        shape.strokeColor = color.cgColor
        shape.fillColor = nil
        shape.lineWidth = width
        shape.lineCap = .round
        shape.lineJoin = .round
        return shape
    }

    private static func fill(_ path: UIBezierPath, _ color: UIColor) -> CAShapeLayer {
        let shape = CAShapeLayer()
        shape.path = path.cgPath
        shape.fillColor = color.cgColor
        return shape
    }

    private static func dot(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ color: UIColor) -> CAShapeLayer {
        fill(UIBezierPath(ovalIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), color)
    }

    private static func line(_ points: [(CGFloat, CGFloat)]) -> UIBezierPath {
        let path = UIBezierPath()
        for (index, point) in points.enumerated() {
            let p = CGPoint(x: point.0, y: point.1)
            if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        return path
    }

    private static func sparkle(_ cx: CGFloat, _ cy: CGFloat, _ arm: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: cx, y: cy - arm)); path.addLine(to: CGPoint(x: cx, y: cy + arm))
        path.move(to: CGPoint(x: cx - arm, y: cy)); path.addLine(to: CGPoint(x: cx + arm, y: cy))
        return path
    }
}
