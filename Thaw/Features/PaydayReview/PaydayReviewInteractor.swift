import Foundation

final class PaydayReviewInteractor: PaydayReviewInteractorProtocol {
    private let store: WantStore
    private let reminders: Reminders
    let wants: [Want]

    init(store: WantStore, reminders: Reminders, wants: [Want]) {
        self.store = store
        self.reminders = reminders
        self.wants = wants
    }

    var budget: Decimal { store.effectiveSettings.funMoney }

    func apply(keeping: Set<UUID>) {
        for want in wants {
            store.decide(id: want.id, keep: keeping.contains(want.id))
        }
        reminders.refresh(requestingPermission: false)
        DataChange.post()
    }
}
