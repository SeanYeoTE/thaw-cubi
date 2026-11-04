import Foundation

final class SavedInteractor: SavedInteractorProtocol {
    weak var output: SavedInteractorOutput?
    private let store: WantStore
    private var observer: DataChangeObserver?

    // Explicit deinit: the synthesized one on a MainActor class with weak refs corrupts the heap in the test host.
    deinit {}

    init(store: WantStore) {
        self.store = store
        observer = DataChangeObserver { [weak self] in self?.output?.dataDidChange() }
    }

    var wants: [Want] { store.wants }
    var activeGoals: [Goal] { store.activeGoals }
    var finishedGoals: [Goal] { store.finishedGoals }
    var inviteHiddenUntil: Date? { store.goalInviteHiddenUntil }

    func pendingPool(now: Date) -> PendingPool { store.pendingPool(now: now) }

    func hideInvite(until: Date) { store.hideGoalInvite(until: until) }
}
