import Foundation

final class SavedInteractor: SavedInteractorProtocol {
    private let store: WantStore

    init(store: WantStore) {
        self.store = store
    }

    var wants: [Want] { store.wants }
}
