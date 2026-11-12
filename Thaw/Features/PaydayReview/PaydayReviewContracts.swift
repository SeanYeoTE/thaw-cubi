import Foundation

enum ReviewChoice: Int, CaseIterable, Equatable {
    case keep, wait, letGo

    var title: String {
        switch self {
        case .keep: return "Keep"
        case .wait: return "Wait"
        case .letGo: return "Let go"
        }
    }
}

struct ReviewRowViewModel: Equatable {
    let id: UUID
    let name: String
    let reasonText: String
    let priceText: String
    let choice: ReviewChoice
    /// VoiceOver labels for the Keep, Wait and Let go buttons, in `ReviewChoice` order.
    let choiceLabels: [String]
    let spokenSummary: String
}

struct PaydayReviewContent {
    let budgetCaption: String
    let budgetText: String
    let rows: [ReviewRowViewModel]
}

struct PaydayReviewSummary: Equatable {
    let fraction: Double
    let isOver: Bool
    let statusText: String
    let ctaTitle: String
}

protocol PaydayReviewViewProtocol: AnyObject {
    func render(_ content: PaydayReviewContent)
    func update(_ summary: PaydayReviewSummary, animated: Bool)
    func showDiscardConfirmation()
    func playSuccessFeedback()
}

protocol PaydayReviewPresenterProtocol: AnyObject {
    func viewDidLoad()
    func setChoice(id: UUID, choice: ReviewChoice)
    func tapCTA()
    func tapClose()
    func confirmDiscard()
}

protocol PaydayReviewInteractorProtocol: AnyObject {
    var wants: [Want] { get }
    var budget: Decimal { get }
    /// Buys Keep wants, moves Wait wants to the next payday and skips Let go wants.
    func apply(choices: [UUID: ReviewChoice])
}

protocol PaydayReviewRouterProtocol: AnyObject {
    func dismiss()
}
