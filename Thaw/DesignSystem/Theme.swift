import UIKit

enum Theme {
    static let background = UIColor(hex: 0xF2F7F9)
    static let surface = UIColor(hex: 0xFFFFFF)
    static let border = UIColor(hex: 0xDDE7EC)
    static let track = UIColor(hex: 0xE3ECF0)
    static let ink = UIColor(hex: 0x0D2230)
    static let inkSecondary = UIColor(hex: 0x4F6370)
    static let accent = UIColor(hex: 0x08708F)
    static let warm = UIColor(hex: 0xE8875A)
    static let paydayCard = UIColor(hex: 0x0D2230)
    static let paydayLabel = UIColor(hex: 0xC7D5DD)
    static let paydaySubtext = UIColor(hex: 0xF2C6B4)
    static let cubeFill = UIColor(hex: 0xD9EEF5)
    static let cubeStroke = UIColor(hex: 0x6FB7CF)
    static let cubeOutline = UIColor(hex: 0x08708F)
    static let ember = UIColor(hex: 0xC2560F)
    static let glow = UIColor(hex: 0xFBE3D3)
    static let puddle = UIColor(hex: 0xBFE3EF)
    static let meterTrack = UIColor(hex: 0x2A4150)
    static let radioDot = UIColor(hex: 0x9FB2BD)
    static let toggleBorder = UIColor(hex: 0xC3D0D7)
    static let toggleText = UIColor(hex: 0x2F4653)
    static let divider = UIColor(hex: 0xEDF2F5)

    enum Radius {
        static let card: CGFloat = 16
        static let pill: CGFloat = 22
    }

    enum Spacing {
        static let screen: CGFloat = 20
        static let gap: CGFloat = 12
    }
}

enum ThawFont {
    private static func style(for size: CGFloat) -> UIFont.TextStyle {
        switch size {
        case 30...: return .largeTitle
        case 24..<30: return .title1
        case 20..<24: return .title2
        case 17..<20: return .headline
        case 15..<17: return .body
        case 13..<15: return .footnote
        default: return .caption1
        }
    }

    private static func scaled(_ font: UIFont, for size: CGFloat) -> UIFont {
        UIFontMetrics(forTextStyle: style(for: size)).scaledFont(for: font, maximumPointSize: size * 2.4)
    }

    static func display(_ size: CGFloat) -> UIFont {
        scaled(UIFont(name: "BricolageGrotesque-96ptExtraBold", size: size)
            ?? UIFont.systemFont(ofSize: size, weight: .heavy), for: size)
    }

    static func body(_ size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        scaled(UIFont.systemFont(ofSize: size, weight: weight), for: size)
    }

    static func money(_ size: CGFloat, weight: UIFont.Weight = .semibold) -> UIFont {
        scaled(UIFont.monospacedDigitSystemFont(ofSize: size, weight: weight), for: size)
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

enum ThawAppearance {
    static func apply() {
        let navigation = UINavigationBarAppearance()
        navigation.configureWithDefaultBackground()
        navigation.backgroundColor = Theme.background
        navigation.shadowColor = .clear
        navigation.titleTextAttributes = [.font: ThawFont.body(17, weight: .semibold), .foregroundColor: Theme.ink]
        navigation.largeTitleTextAttributes = [.font: ThawFont.display(36), .foregroundColor: Theme.ink]
        UINavigationBar.appearance().standardAppearance = navigation
        UINavigationBar.appearance().scrollEdgeAppearance = navigation
        UINavigationBar.appearance().compactAppearance = navigation
        UINavigationBar.appearance().tintColor = Theme.accent
    }
}
