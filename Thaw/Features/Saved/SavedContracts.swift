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
        /// Full sentence for VoiceOver.
        let spoken: String
    }
    let stats: [Stat]
}

struct SavedCubiViewModel: Equatable {
    let mood: CubiMood
    let line: String
}

struct SavedMonthlyAmount: Equatable, Identifiable {
    let month: Date
    let amount: Double
    var id: Date { month }
}

struct SavedViewModel {
    let cubi: SavedCubiViewModel
    let savedText: String
    let monthlySaved: [SavedMonthlyAmount]
    let progress: SavedProgressViewModel?
    let emptyText: String?
    let history: [SavedHistoryRow]
}

struct SavedDeleteConfirmation: Equatable {
    let title: String
    let message: String
    let deleteTitle: String
    let cancelTitle: String
}

protocol SavedViewProtocol: AnyObject {
    func render(_ model: SavedViewModel)
    /// Asks before deleting; confirming calls `confirmDelete(id:)`.
    func showDeleteConfirmation(id: UUID, confirmation: SavedDeleteConfirmation)
}

protocol SavedPresenterProtocol: AnyObject {
    func viewWillAppear()
    func tapEdit(id: UUID)
    func tapDelete(id: UUID)
    func confirmDelete(id: UUID)
}

protocol SavedInteractorProtocol: AnyObject {
    var output: SavedInteractorOutput? { get set }
    var wants: [Want] { get }
    var funMoney: Decimal { get }
    func delete(_ id: UUID)
}

protocol SavedInteractorOutput: AnyObject {
    func dataDidChange()
}

protocol SavedRouterProtocol: AnyObject {
    /// Opens the edit screen for a decided want.
    func showEdit(id: UUID)
}
