import Foundation
@testable import Thaw

enum Fixture {
    static func want(_ name: String, _ price: Decimal, reason: String = "Because") -> Want {
        Want(id: UUID(), name: name, price: price, reason: reason, frozenOn: .now, progress: 0.5,
             status: .cooling, thawsAt: .now)
    }
}
