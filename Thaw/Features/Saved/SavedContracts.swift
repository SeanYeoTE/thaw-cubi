import Foundation

struct SavedHistoryRow: Equatable {
    let name: String
    let priceText: String
    let outcome: String
    let dateText: String
    let isSkipped: Bool
}

struct SavedProgressViewModel: Equatable {
    struct Stat: Equatable {
        let value: String
        let caption: String
    }
    let stats: [Stat]
}

struct SavedViewModel {
    let savedText: String
    let progress: SavedProgressViewModel?
    let emptyText: String?
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
    var funMoney: Decimal { get }
}

protocol SavedRouterProtocol: AnyObject {}
