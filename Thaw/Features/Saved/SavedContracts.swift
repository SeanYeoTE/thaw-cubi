import Foundation

struct SavedHistoryRow: Equatable {
    let name: String
    let priceText: String
    let outcome: String
    let dateText: String
    let isSkipped: Bool
}

struct SavedViewModel {
    let savedText: String
    let skippedText: String
    let pattern: String
    let history: [SavedHistoryRow]
}

protocol SavedViewProtocol: AnyObject {
    func render(_ model: SavedViewModel)
}

protocol SavedPresenterProtocol: AnyObject {
    func viewWillAppear()
}

protocol SavedInteractorProtocol: AnyObject {
    var wants: [Want] { get }
}

protocol SavedRouterProtocol: AnyObject {}
