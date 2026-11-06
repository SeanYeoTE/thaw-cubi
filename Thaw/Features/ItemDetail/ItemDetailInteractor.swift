import Foundation

final class ItemDetailInteractor: ItemDetailInteractorProtocol {
    private let store: WantStore
    private let reminders: Reminders
    private let original: Want

    init(store: WantStore, reminders: Reminders, want: Want) {
        self.store = store
        self.reminders = reminders
        self.original = want
    }

    var want: Want { store.want(id: original.id) ?? original }

    var wantExists: Bool { store.want(id: original.id) != nil }

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
