import Foundation

final class PaydayPreviewInteractor: PaydayPreviewInteractorProtocol {
    private let store: WantStore
    private let reminders: Reminders

    init(store: WantStore, reminders: Reminders) {
        self.store = store
        self.reminders = reminders
    }

    var reviewQueue: [Want] { store.reviewQueue }
    var funMoney: Decimal { store.effectiveSettings.funMoney }

    func remindTonight(completion: @escaping () -> Void) {
        reminders.remindTonight(completion: completion)
    }
}
