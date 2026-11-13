import Foundation

final class StillWantItInteractor: StillWantItInteractorProtocol {
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

    func skip(_ want: Want) {
        store.update(want.id, status: .skipped)
        reminders.refresh(requestingPermission: false)
    }

    func buy(_ want: Want) {
        store.decide(id: want.id, keep: true)
        reminders.refresh(requestingPermission: false)
    }

    func wait(_ want: Want) {
        store.decide(id: want.id, keep: false)
        reminders.refresh(requestingPermission: false)
    }

    func publishChange() {
        DataChange.post()
    }
}
