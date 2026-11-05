import Foundation

/// Share-extension interactor for the AddWant module: writes a `SharedDraft` to the app-group inbox
/// instead of the app's store; the app ingests it the next time it opens.
final class ShareAddInteractor: AddWantInteractorProtocol {
    let draft: AddWantDraft?
    private let inbox: ShareInbox
    private let now: () -> Date
    private(set) var didSave = false

    init(draft: AddWantDraft, inbox: ShareInbox = .shared, now: @escaping () -> Date = { .now }) {
        self.draft = draft
        self.inbox = inbox
        self.now = now
    }

    var editing: Want? { nil }

    // The app's settings live in its own container; the presenter's draft note doesn't quote them.
    var settings: PaydaySettings { .default }

    func add(name: String, price: Decimal, reason: String) {
        let shared = SharedDraft(id: UUID(), name: name, price: price, reason: reason, link: draft?.link, createdAt: now())
        do {
            try inbox.append(shared)
            didSave = true
        } catch {
            didSave = false
        }
    }

    func save(name: String, price: Decimal, reason: String) {}
}
