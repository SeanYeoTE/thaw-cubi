import Foundation

struct PaydayPreviewViewModel {
    let title: String
    let body: String
}

protocol PaydayPreviewViewProtocol: AnyObject {
    func render(_ model: PaydayPreviewViewModel)
    func setReminderBusy()
    func playSuccessFeedback()
}

protocol PaydayPreviewPresenterProtocol: AnyObject {
    func viewDidLoad()
    func tapReview()
    func tapRemindTonight()
    func tapClose()
}

protocol PaydayPreviewInteractorProtocol: AnyObject {
    var reviewQueue: [Want] { get }
    var funMoney: Decimal { get }
    func remindTonight(completion: @escaping () -> Void)
}

protocol PaydayPreviewRouterProtocol: AnyObject {
    func showReview(wants: [Want])
    func dismiss()
}
