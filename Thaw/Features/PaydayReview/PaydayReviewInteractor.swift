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
    var timerThreshold: Decimal { store.effectiveSettings.timerThreshold }

    func apply(choices: [UUID: ReviewChoice]) {
        for want in wants {
            switch choices[want.id] ?? .wait {
            case .keep: store.decide(id: want.id, keep: true)
            case .wait: store.decide(id: want.id, keep: false)
            case .letGo: store.update(want.id, status: .skipped)
            }
        }
        reminders.refresh(requestingPermission: false)
        DataChange.post()
    }
}
