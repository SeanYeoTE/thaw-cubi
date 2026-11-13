import Foundation

struct StillWantItViewModel {
    let progressText: String
    let name: String
    let priceText: String
    let quote: String
    let dateText: String
    let budgetCaption: String
    let budgetText: String
    let meterFraction: Double
    let meterIsOver: Bool
    let meterText: String
    let letGoTitle: String
    let buyTitle: String
    let waitTitle: String
}

protocol StillWantItViewProtocol: AnyObject {
    func render(_ model: StillWantItViewModel)
    /// Plays the success haptic and the Cubi moment, then calls `completion` once.
    func showSkipMoment(line: String, completion: @escaping () -> Void)
    /// Disables Let go, Buy it and Wait a payday while a decision is applied or the screen is leaving.
    func setActionsEnabled(_ enabled: Bool)
}

protocol StillWantItPresenterProtocol: AnyObject {
    func viewDidLoad()
    func tapLetGo()
    func tapBuy()
    func tapWait()
    func tapClose()
}

protocol StillWantItInteractorProtocol: AnyObject {
    var wants: [Want] { get }
    var budget: Decimal { get }
    var timerThreshold: Decimal { get }
    func skip(_ want: Want)
    func buy(_ want: Want)
    func wait(_ want: Want)
    func publishChange()
}

protocol StillWantItRouterProtocol: AnyObject {
    /// Dismisses the flow, then runs `completion`.
    func dismiss(completion: (() -> Void)?)
}
