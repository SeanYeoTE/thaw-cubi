import Foundation

struct PaydayRowViewModel: Equatable {
    let id: UUID
    let row: WantRowModel
}

struct PaydaySectionViewModel: Equatable {
    let title: String
    let detail: String
    let rows: [PaydayRowViewModel]
}

/// Spoken-for against this payday's fun money: "S$120 left" or "S$402 over".
struct PaydayBudgetViewModel: Equatable {
    /// Big figure: "S$120 left" or "S$402 over".
    let headline: String
    /// "S$702 thawing · S$300 fun money".
    let caption: String
    let spoken: String
    /// How full the bar is, 0...1 (the view clamps).
    let fillFraction: Double
    /// Where the 100% marker sits on the bar: 1 when it fits, fun money / spoken-for when over.
    let markerFraction: Double
    let isOver: Bool
}

enum PaydayReminderState: Equatable {
    case idle, busy, set
}

struct PaydayViewModel: Equatable {
    let title: String
    let mood: CubiMood
    /// Big number: "14 days", "Today" or "3 ready".
    let heroValue: String
    /// One short line under it: "to Tue, 25 Nov" or "S$600 · S$300 fun money".
    let heroCaption: String
    let heroSpoken: String
    /// nil when nothing is cooling: the empty state carries Cubi instead.
    let showsCubi: Bool
    let budget: PaydayBudgetViewModel?
    /// nil hides Review and Remind me tonight (nothing ready).
    let reviewTitle: String?
    let reminderTitle: String
    let reminderState: PaydayReminderState
    let sections: [PaydaySectionViewModel]
    let emptyLine: String?
}

struct PaydaySnapshot {
    let cooling: [Want]
    let reviewQueue: [Want]
    let payday: PaydaySchedule
    let settings: PaydaySettings
    let now: Date
}

protocol PaydayViewProtocol: AnyObject {
    func render(_ model: PaydayViewModel)
    func playSuccessFeedback()
}

protocol PaydayPresenterProtocol: AnyObject {
    func viewWillAppear()
    func tapReview()
    func tapRemindTonight()
    func tapWant(id: UUID)
}

protocol PaydayInteractorProtocol: AnyObject {
    var output: PaydayInteractorOutput? { get set }
    func snapshot() -> PaydaySnapshot
    func remindTonight(completion: @escaping () -> Void)
}

protocol PaydayInteractorOutput: AnyObject {
    /// Wants changed, or a timer thawed.
    func dataDidChange()
}

protocol PaydayRouterProtocol: AnyObject {
    func showReview(wants: [Want])
    func showItemDetail(id: UUID)
}
