import UIKit

final class ProgressBarView: UIView {
    private let fill = UIView()
    private var fillWidth: NSLayoutConstraint?

    init(fraction: CGFloat, color: UIColor) {
        super.init(frame: .zero)
        backgroundColor = Theme.track
        layer.cornerRadius = 3
        clipsToBounds = true
        fill.backgroundColor = color
        fill.translatesAutoresizingMaskIntoConstraints = false
        addSubview(fill)
        let width = fill.widthAnchor.constraint(equalTo: widthAnchor, multiplier: max(0, min(1, fraction)))
        fillWidth = width
        NSLayoutConstraint.activate([
            fill.leadingAnchor.constraint(equalTo: leadingAnchor),
            fill.topAnchor.constraint(equalTo: topAnchor),
            fill.bottomAnchor.constraint(equalTo: bottomAnchor),
            width,
        ])
        heightAnchor.constraint(equalToConstant: 6).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}

final class CardView: UIView {
    init() {
        super.init(frame: .zero)
        backgroundColor = Theme.surface
        layer.cornerRadius = Theme.Radius.card
        layer.borderWidth = 1
        layer.borderColor = Theme.border.cgColor
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}

final class PillButton: UIButton {
    enum Style { case primary, secondary, quiet }

    init(title: String, style: Style) {
        super.init(frame: .zero)
        var config: UIButton.Configuration
        switch style {
        case .primary:
            config = .filled()
            config.baseBackgroundColor = Theme.accent
            config.baseForegroundColor = .white
        case .secondary:
            config = .filled()
            config.baseBackgroundColor = Theme.surface
            config.baseForegroundColor = Theme.ink
            config.background.strokeColor = Theme.border
            config.background.strokeWidth = 1
        case .quiet:
            config = .plain()
            config.baseForegroundColor = Theme.inkSecondary
        }
        config.title = title
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var updated = attributes
            updated.font = ThawFont.body(16, weight: .semibold)
            return updated
        }
        configuration = config
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}

final class PaydayCardView: UIControl {
    init(daysLeft: Int, nextPayday: String, subtitle: String) {
        super.init(frame: .zero)
        backgroundColor = Theme.paydayCard
        layer.cornerRadius = Theme.Radius.pill

        let cube = CubeIconView()
        let label = UILabel()
        label.text = "Next payday · \(nextPayday)"
        label.font = ThawFont.body(14)
        label.textColor = Theme.paydayLabel

        let days = UILabel()
        days.text = "\(daysLeft) days"
        days.font = ThawFont.display(34)
        days.textColor = .white

        let sub = UILabel()
        sub.text = subtitle
        sub.font = ThawFont.body(14)
        sub.textColor = Theme.paydaySubtext
        sub.numberOfLines = 0

        let text = UIStackView(arrangedSubviews: [label, days, sub])
        text.axis = .vertical
        text.spacing = 2

        let row = UIStackView(arrangedSubviews: [cube, text])
        row.alignment = .center
        row.spacing = 16
        row.translatesAutoresizingMaskIntoConstraints = false
        row.isUserInteractionEnabled = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}

final class CubeIconView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 64).isActive = true
        heightAnchor.constraint(equalToConstant: 68).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func draw(_ rect: CGRect) {
        let scale = rect.width / 160
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * scale, y: y * scale) }
        let body = UIBezierPath()
        body.move(to: p(48, 24)); body.addLine(to: p(114, 24)); body.addLine(to: p(122, 36))
        body.addLine(to: p(140, 42)); body.addLine(to: p(140, 116))
        body.addQuadCurve(to: p(112, 144), controlPoint: p(140, 144))
        body.addLine(to: p(48, 144))
        body.addQuadCurve(to: p(20, 116), controlPoint: p(20, 144))
        body.addLine(to: p(20, 52))
        body.addQuadCurve(to: p(48, 24), controlPoint: p(20, 24))
        body.close()
        Theme.cubeFill.setFill()
        body.fill()
        Theme.cubeStroke.setStroke()
        body.lineWidth = 7 * scale
        body.lineJoinStyle = .round
        body.stroke()

        let eyes = UIBezierPath()
        eyes.move(to: p(53, 86)); eyes.addLine(to: p(71, 86))
        eyes.move(to: p(89, 86)); eyes.addLine(to: p(107, 86))
        eyes.lineWidth = 8 * scale
        eyes.lineCapStyle = .round
        Theme.ink.setStroke()
        eyes.stroke()

        let mouth = UIBezierPath()
        mouth.move(to: p(62, 112))
        for x in stride(from: 68, through: 98, by: 6) {
            mouth.addLine(to: p(CGFloat(x), x.isMultiple(of: 12) ? 112 : 107))
        }
        mouth.lineWidth = 6 * scale
        mouth.lineCapStyle = .round
        mouth.lineJoinStyle = .round
        Theme.ink.setStroke()
        mouth.stroke()
    }
}
