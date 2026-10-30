import Foundation

nonisolated final class WantStore: @unchecked Sendable {
    static let shared = WantStore()

    private(set) var wants: [Want]
    let payday: PaydaySchedule
    private let calendar = Calendar(identifier: .gregorian)

    init(wants: [Want] = WantStore.fixtureWants(), payday: PaydaySchedule = WantStore.fixturePayday()) {
        self.wants = wants
        self.payday = payday
    }

    var cooling: [Want] { wants.filter { $0.status == .cooling } }
    var saved: [Want] { wants.filter { $0.status != .cooling } }

    func add(name: String, price: Decimal, reason: String) {
        let want = Want(id: UUID(), name: name, price: Self.rounded(price), reason: reason,
                        frozenOn: .now, progress: 0, status: .cooling)
        wants.insert(want, at: 0)
    }

    func update(_ id: UUID, status: Want.Status) {
        guard let index = wants.firstIndex(where: { $0.id == id }) else { return }
        wants[index].status = status
    }

    func want(id: UUID) -> Want? { wants.first { $0.id == id } }

    static func rounded(_ value: Decimal) -> Decimal {
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, 2, .plain)
        return result
    }

    static func fixtureWants() -> [Want] {
        let now = Date.now
        return [
            Want(id: UUID(), name: "Phone case", price: 24, reason: "Mine has a crack near the camera.",
                 frozenOn: now.addingTimeInterval(-86_400 * 1), progress: 0.8, status: .cooling),
            Want(id: UUID(), name: "Mechanical keyboard", price: 189,
                 reason: "My current one double-types. I type all day for work.",
                 frozenOn: now.addingTimeInterval(-86_400 * 2), progress: 0.59, status: .cooling),
            Want(id: UUID(), name: "Linen overshirt", price: 69, reason: "Good for the hot weather.",
                 frozenOn: now.addingTimeInterval(-86_400 * 4), progress: 0.4, status: .cooling),
            Want(id: UUID(), name: "Espresso grinder", price: 420, reason: "Pre-ground tastes flat.",
                 frozenOn: now.addingTimeInterval(-86_400 * 6), progress: 0.2, status: .cooling),
        ]
    }

    static func fixturePayday() -> PaydaySchedule {
        var components = DateComponents()
        components.year = 2026
        components.month = 11
        components.day = 25
        components.hour = 9
        let date = Calendar(identifier: .gregorian).date(from: components) ?? .now
        return PaydaySchedule(nextPayday: date, funMoney: 300)
    }
}
