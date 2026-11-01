import Foundation

struct SavedViewModel {
    let keptText: String
    let goalTitle: String
    let goalFraction: Double
    let goalCaption: String
    let skippedText: String
    let pattern: String
    let skippedLines: [String]
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
