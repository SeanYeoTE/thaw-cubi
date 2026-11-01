import Foundation

struct ReviewRowViewModel: Equatable {
    let id: UUID
    let name: String
    let reasonText: String
    let priceText: String
    let isKeeping: Bool
}

struct PaydayReviewContent {
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
    func setKeeping(id: UUID, keeping: Bool)
    func tapCTA()
    func tapClose()
    func confirmDiscard()
}

protocol PaydayReviewInteractorProtocol: AnyObject {
    var wants: [Want] { get }
    var budget: Decimal { get }
    /// Keeps the wants in `keeping`, waits on the rest.
    func apply(keeping: Set<UUID>)
}

protocol PaydayReviewRouterProtocol: AnyObject {
    func dismiss()
}
