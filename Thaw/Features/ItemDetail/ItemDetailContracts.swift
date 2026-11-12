import Foundation

struct ItemDetailViewModel {
    let name: String
    let priceText: String
    let frozenText: String
    let daysText: String
    let captionText: String
    let progress: Double
    let isTimer: Bool
    let quote: String
    /// "Open link · example.com" when the want has a link.
    let linkText: String?
    let letGoTitle: String
}

protocol ItemDetailViewProtocol: AnyObject {
    func render(_ model: ItemDetailViewModel)
    /// Plays the success haptic and the Cubi moment, then calls `completion` once.
    func showSkipMoment(line: String, completion: @escaping () -> Void)
    /// Destructive-style alert; calls `onConfirm` only if the user confirms.
    func showLetGoConfirmation(title: String, confirmTitle: String, cancelTitle: String, onConfirm: @escaping () -> Void)
}

protocol ItemDetailPresenterProtocol: AnyObject {
    func viewDidLoad()
    func tapDecide()
    func tapLetGo()
    func tapEdit()
    func tapLink()
    func didEdit()
}

protocol ItemDetailInteractorProtocol: AnyObject {
    var want: Want { get }
    /// False once the want was deleted (from the edit screen).
    var wantExists: Bool { get }
    var settings: PaydaySettings { get }
    func skip()
}

protocol ItemDetailRouterProtocol: AnyObject {
    func showDecideNow(want: Want)
    func showEdit(wantID: UUID)
    func pop()
    func openLink(_ url: URL)
}
