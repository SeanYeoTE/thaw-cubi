import Foundation

extension Notification.Name {
    /// Posted after a flow changes wants (review, decide now, skip) so lists behind a sheet can refresh.
    static let thawDataChanged = Notification.Name("thaw.dataChanged")
}

enum DataChange {
    static func post() {
        NotificationCenter.default.post(name: .thawDataChanged, object: nil)
    }
}

/// Interactors use this to forward `DataChange` notifications to their presenter.
@MainActor
final class DataChangeObserver {
    private var token: NSObjectProtocol?

    init(handler: @escaping @MainActor () -> Void) {
        token = NotificationCenter.default.addObserver(forName: .thawDataChanged, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { handler() }
        }
    }

    func stop() {
        if let token { NotificationCenter.default.removeObserver(token) }
        token = nil
    }
}
