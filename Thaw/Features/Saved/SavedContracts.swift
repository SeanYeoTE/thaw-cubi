import Foundation

struct SavedHistoryRow: Equatable {
    let id: UUID
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

struct SavedCubiViewModel: Equatable {
    let mood: CubiMood
    let line: String
}

struct SavedViewModel {
    let cubi: SavedCubiViewModel
    let savedText: String
    let progress: SavedProgressViewModel?
    let emptyText: String?
    let history: [SavedHistoryRow]
}

/// What the Edit action sheet on a History row can do.
enum SavedDecisionOption: Equatable {
    case moveBackToCooling
    case markBought
    case markSkipped
}

struct SavedDecisionChoice: Equatable {
    let option: SavedDecisionOption
    let title: String
}

struct SavedDecisionSheet: Equatable {
    let title: String
    let message: String?
    let choices: [SavedDecisionChoice]
    let cancelTitle: String
}

struct SavedDeleteConfirmation: Equatable {
    let title: String
    let message: String
    let deleteTitle: String
    let cancelTitle: String
}

protocol SavedViewProtocol: AnyObject {
    func render(_ model: SavedViewModel)
    /// Shows an action sheet for the row; picking a choice calls `chooseDecisionOption(id:option:)`.
    func showDecisionOptions(id: UUID, sheet: SavedDecisionSheet)
    /// Asks before deleting; confirming calls `confirmDelete(id:)`.
    func showDeleteConfirmation(id: UUID, confirmation: SavedDeleteConfirmation)
}

protocol SavedPresenterProtocol: AnyObject {
    func viewWillAppear()
    func tapEditDecision(id: UUID)
    func chooseDecisionOption(id: UUID, option: SavedDecisionOption)
    func tapDelete(id: UUID)
    func confirmDelete(id: UUID)
}

protocol SavedInteractorProtocol: AnyObject {
    var output: SavedInteractorOutput? { get set }
    var wants: [Want] { get }
    var funMoney: Decimal { get }
    func reopen(_ id: UUID)
    func setDecision(_ id: UUID, to status: Want.Status)
    func delete(_ id: UUID)
}

protocol SavedInteractorOutput: AnyObject {
    func dataDidChange()
}

protocol SavedRouterProtocol: AnyObject {}
