import Foundation

struct StillWantItViewModel {
    let progressText: String
    let question: String
    let priceText: String
    let quote: String
    let funText: String
    let keepTitle: String
    /// Set only when the user has active goals.
    let skipHint: String?
}

protocol StillWantItViewProtocol: AnyObject {
    func render(_ model: StillWantItViewModel)
    /// Plays the success haptic and the Cubi moment, then calls `completion` once.
    func showSkipMoment(line: String, completion: @escaping () -> Void)
}

protocol StillWantItPresenterProtocol: AnyObject {
    func viewDidLoad()
    func tapSkip()
    func tapBuy()
    func tapWait()
    func tapClose()
}

protocol StillWantItInteractorProtocol: AnyObject {
    var wants: [Want] { get }
    var budget: Decimal { get }
    var hasActiveGoals: Bool { get }
    func skip(_ want: Want)
    func buy(_ want: Want)
    func wait(_ want: Want)
    func publishChange()
}

protocol StillWantItRouterProtocol: AnyObject {
    /// Dismisses the flow, then runs `completion`.
    func dismiss(completion: (() -> Void)?)
}
