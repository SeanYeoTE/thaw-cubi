import UIKit

enum Theme {
    static let background = UIColor(light: 0xF2F7F9, dark: 0x0B141B)
    static let surface = UIColor(light: 0xFFFFFF, dark: 0x14222C)
    /// Decorative card and divider edges only; under 3:1, so never the only way to see a control.
    static let border = UIColor(light: 0xDDE7EC, dark: 0x26394A)
    /// Edges of interactive controls (fields, unselected chips, radio dots, toggles): 3.68:1 on surface,
    /// 3.41:1 on background in light, and above 4:1 on both in dark, meeting WCAG 1.4.11.
    static let controlBorder = UIColor(light: 0x72889A, dark: 0x7C93A5)
    static let track = UIColor(light: 0xE3ECF0, dark: 0x21323E)
    static let ink = UIColor(light: 0x0D2230, dark: 0xE9F1F5)
    static let inkSecondary = UIColor(light: 0x4F6370, dark: 0x9DB1BE)
    static let accent = UIColor(light: 0x08708F, dark: 0x4DB8D6)
    /// Text and icons on an `accent` fill.
    static let onAccent = UIColor(light: 0xFFFFFF, dark: 0x0D2230)
    /// Over-budget fill on the dark meter track. Too light for light backgrounds; use `timer` there.
    static let warm = UIColor(hex: 0xE8875A)
    /// Quick-thaw tone on the background: 4.74:1 on light surface; the lighter `warm` tone on dark.
    static let timer = UIColor(light: 0xB8572A, dark: 0xE8875A)
    /// Payday and Stats cards stay dark in both appearances, so their white text and meter always contrast.
    static let paydayCard = UIColor(light: 0x0D2230, dark: 0x1B3445)
    static let paydayLabel = UIColor(hex: 0xC7D5DD)
    static let paydaySubtext = UIColor(hex: 0xF2C6B4)
    // Cubi is artwork and keeps its light-mode palette, so he reads as the same ice cube in both appearances.
    static let cubeFill = UIColor(hex: 0xD9EEF5)
    static let cubeStroke = UIColor(hex: 0x6FB7CF)
    static let cubeOutline = UIColor(hex: 0x08708F)
    static let cubiInk = UIColor(hex: 0x0D2230)
    static let cubiAccent = UIColor(hex: 0x08708F)
    static let ember = UIColor(hex: 0xC2560F)
    static let glow = UIColor(hex: 0xFBE3D3)
    static let puddle = UIColor(hex: 0xBFE3EF)
    static let meterTrack = UIColor(light: 0x2A4150, dark: 0x0D1C27)
    static let radioDot = controlBorder
    static let toggleBorder = controlBorder
    static let toggleText = UIColor(light: 0x2F4653, dark: 0xC3D3DC)
    static let divider = UIColor(light: 0xEDF2F5, dark: 0x1D2D38)
    static let destructive = UIColor(light: 0xB3261E, dark: 0xFF8A80)

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

    /// Uncapped, so text reaches the system maximum at every size (a cap fails the Dynamic Type audit as
    /// "partially unsupported"). Display sizes (26 pt and up) map to `.title1`/`.largeTitle`, which grow at most
    /// about 2.1x and 1.8x at AX5, so their titles stay within the layouts without a cap.
    private static func scaled(_ font: UIFont, for size: CGFloat) -> UIFont {
        UIFontMetrics(forTextStyle: style(for: size)).scaledFont(for: font)
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
    /// A colour that follows the interface style.
    convenience init(light: UInt32, dark: UInt32) {
        self.init { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) }
    }

    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension UIView {
    /// Sets a layer border that re-resolves when the interface style changes (`CGColor` is not dynamic).
    func setBorderColor(_ color: UIColor) {
        layer.borderColor = color.resolvedColor(with: traitCollection).cgColor
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: UIView, _) in
            view.layer.borderColor = color.resolvedColor(with: view.traitCollection).cgColor
        }
    }
}

/// The user's appearance choice, applied to every window.
enum AppearanceMode: Int, CaseIterable {
    case system, light, dark

    private static let key = "appearanceMode"

    static var saved: AppearanceMode {
        get { AppearanceMode(rawValue: UserDefaults.standard.integer(forKey: key)) ?? .system }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var style: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }

    func apply(to window: UIWindow) {
        window.overrideUserInterfaceStyle = style
    }

    func apply(to scene: UIWindowScene?) {
        scene?.windows.forEach(apply)
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
