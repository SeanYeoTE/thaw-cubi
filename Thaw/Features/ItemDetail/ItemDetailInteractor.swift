import Foundation

final class ItemDetailInteractor: ItemDetailInteractorProtocol {
    private let store: WantStore
    private let reminders: Reminders
    let want: Want

    init(store: WantStore, reminders: Reminders, want: Want) {
        self.store = store
        self.reminders = reminders
        self.want = want
    }

    var settings: PaydaySettings { store.effectiveSettings }

    func waitOnePayday() {
        store.decide(id: want.id, keep: false)
        DataChange.post()
        reminders.refresh(requestingPermission: false)
    }

    func skip() {
        store.update(want.id, status: .skipped)
        DataChange.post()
        reminders.refresh(requestingPermission: false)
    }
}
