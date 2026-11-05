import Foundation

struct ItemDetailViewModel {
    let name: String
    let subtitle: String
    let daysText: String
    let untilText: String
    let progress: Double
    let isTimer: Bool
    let quote: String
    let thawsText: String
}

protocol ItemDetailViewProtocol: AnyObject {
    func render(_ model: ItemDetailViewModel)
    /// Plays the success haptic and the Cubi moment, then calls `completion` once.
    func showSkipMoment(line: String, completion: @escaping () -> Void)
}

protocol ItemDetailPresenterProtocol: AnyObject {
    func viewDidLoad()
    func tapWait()
    func tapDecide()
    func tapSkip()
    func tapEdit()
    func didEdit()
}

protocol ItemDetailInteractorProtocol: AnyObject {
    var want: Want { get }
    var settings: PaydaySettings { get }
    func waitOnePayday()
    func skip()
}

protocol ItemDetailRouterProtocol: AnyObject {
    func showDecideNow(want: Want)
    func showEdit(wantID: UUID)
    func pop()
}
