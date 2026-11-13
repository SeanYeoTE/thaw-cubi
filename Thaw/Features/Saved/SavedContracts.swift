import Foundation

/// History filter, stored by raw value under `stats.historyFilter`.
enum SavedHistoryFilter: String, CaseIterable {
    case all, letGo, bought
}

/// Chart range, stored by raw value under `stats.chartRange`.
enum SavedChartRange: String, CaseIterable {
    case sixMonths, oneYear, all
}

struct SavedHeroViewModel: Equatable {
    let mood: CubiMood
    /// Cubi's line, for VoiceOver only.
    let spokenLine: String
    let savedText: String
    let caption: String
    /// "S$1,240 saved".
    let spoken: String
}

struct SavedStatChip: Equatable {
    let symbol: String?
    let value: String
    let caption: String?
    /// Full sentence, read by VoiceOver and shown when the chip is tapped.
    let spoken: String
}

struct SavedChipExplanation: Equatable {
    let message: String
    let dismissTitle: String
}

struct SavedMonthlyAmount: Equatable, Identifiable {
    /// Start of the month.
    let month: Date
    let amount: Double
    let isCurrent: Bool
    /// "Oct · S$320", shown when the bar is selected.
    let selectionText: String
    let spokenMonth: String
    let spokenAmount: String
    var id: Date { month }
}

struct SavedChartViewModel: Equatable {
    let months: [SavedMonthlyAmount]
    let rangeTitles: [String]
    let selectedRange: Int
    let showsRangePicker: Bool
    let showsChart: Bool
    let accessibilityLabel: String

    /// Every month, oldest first: "October 2026, S$320 saved; November 2026, S$0 saved".
    var accessibilityValue: String {
        months.map { "\($0.spokenMonth), \($0.spokenAmount)" }.joined(separator: "; ")
    }
}

struct SavedEmptyViewModel: Equatable {
    let mood: CubiMood
    let line: String
}

struct SavedHistoryRow: Equatable {
    let id: UUID
    let name: String
    let priceText: String
    let isSkipped: Bool
    /// "Shirt, S$69".
    let accessibilityLabel: String
    /// "Let go, decided 3 November 2026".
    let accessibilityValue: String
}

struct SavedHistorySection: Equatable {
    /// Start of the decision month.
    let month: Date
    let title: String
    /// "S$320 saved"; nil when nothing was let go that month.
    let detail: String?
    let rows: [SavedHistoryRow]
}

struct SavedHistoryViewModel: Equatable {
    let filterTitles: [String]
    let selectedFilter: Int
    let sections: [SavedHistorySection]
    /// Short line shown when the filter hides every row.
    let emptyText: String?

    var rows: [SavedHistoryRow] { sections.flatMap(\.rows) }
}

struct SavedViewModel: Equatable {
    let hero: SavedHeroViewModel
    let chips: [SavedStatChip]
    let chart: SavedChartViewModel
    /// Set when nothing is decided yet; the view then shows only the empty state.
    let empty: SavedEmptyViewModel?
    /// nil when nothing is decided yet.
    let history: SavedHistoryViewModel?
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
    /// Shows a stat chip's full sentence.
    func showChipExplanation(_ explanation: SavedChipExplanation)
}

protocol SavedPresenterProtocol: AnyObject {
    func viewWillAppear()
    func tapEdit(id: UUID)
    func tapDelete(id: UUID)
    func confirmDelete(id: UUID)
    func tapChip(at index: Int)
    func selectHistoryFilter(at index: Int)
    func selectChartRange(at index: Int)
}

protocol SavedInteractorProtocol: AnyObject {
    var output: SavedInteractorOutput? { get set }
    var wants: [Want] { get }
    var funMoney: Decimal { get }
    var historyFilter: SavedHistoryFilter { get set }
    var chartRange: SavedChartRange { get set }
    func delete(_ id: UUID)
}

protocol SavedInteractorOutput: AnyObject {
    func dataDidChange()
}

protocol SavedRouterProtocol: AnyObject {
    /// Opens the edit screen for a decided want.
    func showEdit(id: UUID)
}
