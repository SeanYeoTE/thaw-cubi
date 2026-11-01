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
