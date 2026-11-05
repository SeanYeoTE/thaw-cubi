import Foundation
import os

nonisolated final class WantStore: @unchecked Sendable {
    static let shared = WantStore()

    private static let logger = Logger(subsystem: "app.thaw", category: "WantStore")

    private struct Persisted: Codable {
        var wants: [Want]
        var settings: PaydaySettings?
    }

    private(set) var wants: [Want]
    private(set) var settings: PaydaySettings?
    private let fileURL: URL?
    private let legacyPayday: PaydaySchedule?
    private let calendar = Calendar.current

    /// Legacy in-memory store with a fixed payday.
    init(wants: [Want] = WantStore.fixtureWants(), payday: PaydaySchedule = WantStore.fixturePayday()) {
        self.wants = wants
        self.settings = nil
        self.fileURL = nil
        self.legacyPayday = payday
    }

    /// Loads state from `fileURL`; nil keeps everything in memory.
    init(fileURL: URL?) {
        self.fileURL = fileURL
        self.legacyPayday = nil
        var loaded = Persisted(wants: [], settings: nil)
        if let fileURL, let data = try? Data(contentsOf: fileURL) {
            do {
                loaded = try JSONDecoder().decode(Persisted.self, from: data)
            } catch {
                Self.logger.error("Could not decode state: \(error.localizedDescription, privacy: .public)")
            }
        }
        self.wants = loaded.wants
        self.settings = loaded.settings
    }

    static var defaultFileURL: URL? {
        guard let base = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                      appropriateFor: nil, create: true) else { return nil }
        return base.appendingPathComponent("Thaw", isDirectory: true).appendingPathComponent("state.json")
    }

    static func launch(arguments: [String] = ProcessInfo.processInfo.arguments) -> WantStore {
        let url = defaultFileURL
        let isFirstLaunch = url.map { !FileManager.default.fileExists(atPath: $0.path) } ?? false
        if arguments.contains("-thawReset") || arguments.contains("-thawFixture"), let url {
            try? FileManager.default.removeItem(at: url)
        }
        let store = WantStore(fileURL: url)
        if let index = arguments.firstIndex(of: "-thawFixture"),
           arguments.indices.contains(index + 1), arguments[index + 1] == "sprint1" {
            store.wants = fixtureWants(settings: store.effectiveSettings)
            store.persist()
        }
        if let index = arguments.firstIndex(of: "-thawFixture"),
           arguments.indices.contains(index + 1), arguments[index + 1] == "history" {
            store.settings = .default
            store.wants = fixtureHistory()
            store.persist()
        }
#if DEBUG
        // Debug builds start with sample wants so Home and Saved aren't empty while testing.
        if isFirstLaunch, !arguments.contains("-thawReset"), !arguments.contains("-thawFixture") {
            store.settings = .default
            store.wants = fixtureWants(settings: store.effectiveSettings) + fixtureHistory()
            store.persist()
        }
#endif
        return store
    }

    var effectiveSettings: PaydaySettings { settings ?? .default }

    var payday: PaydaySchedule {
        if let legacyPayday { return legacyPayday }
        let current = effectiveSettings
        return PaydaySchedule(nextPayday: current.nextPayday(after: .now, calendar: calendar),
                              funMoney: current.funMoney)
    }

    var daysUntilNext: Int { payday.daysUntilNext }

    var thawedWants: [Want] {
        let now = Date.now
        return cooling.filter { $0.thawsAt <= now }
    }

    func save(settings newSettings: PaydaySettings) {
        settings = newSettings
        persist()
    }

    func decide(id: UUID, keep: Bool, now: Date = .now) {
        guard let index = wants.firstIndex(where: { $0.id == id }) else { return }
        if keep {
            wants[index].status = .bought
        } else {
            wants[index].thawsAt = effectiveSettings.paydayAfter(max(wants[index].thawsAt, now), calendar: calendar)
        }
        persist()
    }

    private func persist() {
        guard let fileURL else { return }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(Persisted(wants: wants, settings: settings))
            try data.write(to: fileURL, options: .atomic)
        } catch {
            Self.logger.error("Could not save state: \(error.localizedDescription, privacy: .public)")
        }
    }

    var cooling: [Want] { wants.filter { $0.status == .cooling } }
    var saved: [Want] { wants.filter { $0.status != .cooling } }

    func add(name: String, price: Decimal, reason: String) {
        let current = effectiveSettings
        let now = Date.now
        let rounded = Self.rounded(price)
        let thawsAt = rounded < current.timerThreshold
            ? calendar.date(byAdding: .day, value: current.timerDays, to: now) ?? now
            : current.nextPayday(after: now, calendar: calendar)
        let want = Want(id: UUID(), name: name, price: rounded, reason: reason,
                        frozenOn: now, progress: 0, status: .cooling, thawsAt: thawsAt)
        wants.insert(want, at: 0)
        persist()
    }

    /// Edits a cooling want's name, price and reason. The thaw date only changes when the price crosses the
    /// timer threshold, and is then counted from the edit time: down means a fresh timer, up means the next
    /// payday after now. Staying on the same side keeps the date, including any Wait already applied.
    func edit(_ id: UUID, name: String, price: Decimal, reason: String, now: Date = .now) {
        guard let index = wants.firstIndex(where: { $0.id == id }), wants[index].status == .cooling else { return }
        let current = effectiveSettings
        let rounded = Self.rounded(price)
        let wasTimer = wants[index].price < current.timerThreshold
        let isTimer = rounded < current.timerThreshold
        if wasTimer != isTimer {
            wants[index].thawsAt = isTimer
                ? calendar.date(byAdding: .day, value: current.timerDays, to: now) ?? now
                : current.nextPayday(after: now, calendar: calendar)
        }
        wants[index].name = name
        wants[index].price = rounded
        wants[index].reason = reason
        persist()
    }

    func update(_ id: UUID, status: Want.Status) {
        guard let index = wants.firstIndex(where: { $0.id == id }) else { return }
        wants[index].status = status
        persist()
    }

    func want(id: UUID) -> Want? { wants.first { $0.id == id } }

    static func rounded(_ value: Decimal) -> Decimal {
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, 2, .plain)
        return result
    }

    static func fixtureWants(now: Date = .now, settings: PaydaySettings = .default,
                             calendar: Calendar = .current) -> [Want] {
        func make(_ name: String, _ price: Decimal, _ reason: String, daysAgo: Int, progress: Double) -> Want {
            let frozenOn = now.addingTimeInterval(-86_400 * Double(daysAgo))
            let thawsAt = price < settings.timerThreshold
                ? calendar.date(byAdding: .day, value: settings.timerDays, to: frozenOn) ?? frozenOn
                : settings.nextPayday(after: now, calendar: calendar)
            return Want(id: UUID(), name: name, price: price, reason: reason, frozenOn: frozenOn,
                        progress: progress, status: .cooling, thawsAt: thawsAt)
        }
        return [
            make("Phone case", 24, "Mine has a crack near the camera.", daysAgo: 1, progress: 0.8),
            make("Mechanical keyboard", 189, "My current one double-types. I type all day for work.",
                 daysAgo: 2, progress: 0.59),
            make("Linen overshirt", 69, "Good for the hot weather.", daysAgo: 4, progress: 0.4),
            make("Espresso grinder", 420, "Pre-ground tastes flat.", daysAgo: 6, progress: 0.2),
        ]
    }

    static func fixtureHistory(now: Date = .now, calendar: Calendar = .current) -> [Want] {
        func decided(_ name: String, _ price: Decimal, _ status: Want.Status, monthsAgo: Int) -> Want {
            let thawsAt = calendar.date(byAdding: .month, value: -monthsAgo, to: now) ?? now
            let frozenOn = thawsAt.addingTimeInterval(-86_400 * 20)
            return Want(id: UUID(), name: name, price: price, reason: "Fixture", frozenOn: frozenOn,
                        progress: 1, status: status, thawsAt: thawsAt)
        }
        return [
            decided("Linen overshirt", 69, .skipped, monthsAgo: 0),
            decided("Mechanical keyboard", 189, .bought, monthsAgo: 0),
            decided("Espresso grinder", 420, .skipped, monthsAgo: 1),
            decided("Wireless earbuds", 159, .skipped, monthsAgo: 2),
            decided("Desk lamp", 45, .bought, monthsAgo: 2),
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
