import Foundation
import UserNotifications
import os

protocol NotificationScheduling: Sendable {
    func requestAuthorizationIfNeeded() async -> Bool
    func schedulePaydayReview(at: Date, thawingCount: Int, total: Decimal) async
    func scheduleTimerThaw(wantID: UUID, name: String, at: Date) async
    func scheduleReminder(at: Date, thawingCount: Int, total: Decimal) async
    /// Identifiers of every pending (not yet delivered) request.
    func pendingIdentifiers() async -> [String]
    func cancel(identifiers: [String]) async
    /// DEBUG builds log every pending request so simulator QA can check what is scheduled.
    func logPending(context: String) async
}

extension NotificationScheduling {
    func pendingIdentifiers() async -> [String] { [] }
    func cancel(identifiers: [String]) async {}
    func logPending(context: String) async {}
}

nonisolated enum ThawNotification {
    static let paydayCategory = "thaw.payday"
    static let reviewNowAction = "thaw.reviewNow"
    static let remindTonightAction = "thaw.remindTonight"
    static let paydayIdentifier = "thaw.payday.review"
    static let reminderIdentifier = "thaw.payday.reminder"
    static let timerPrefix = "thaw.timer."
    /// `userInfo` key on timer-thaw notifications holding the want's UUID string (D7).
    static let wantIDKey = "wantID"

    static func paydayTitle(count: Int) -> String {
        "Payday. \(count) \(count == 1 ? "want has" : "wants have") thawed."
    }

    static func paydayBody(total: Decimal, funMoney: Decimal) -> String {
        "\(Formatting.sgd(total)) thawed. Your fun money is \(Formatting.sgd(funMoney)). Pick what fits before the money goes elsewhere."
    }
}

nonisolated final class UserNotificationScheduler: NotificationScheduling, @unchecked Sendable {
    private static let logger = Logger(subsystem: "app.thaw", category: "Notifications")
    private let funMoney: Decimal

    init(funMoney: Decimal = PaydaySettings.default.funMoney) {
        self.funMoney = funMoney
    }

    private var center: UNUserNotificationCenter { .current() }

    func requestAuthorizationIfNeeded() async -> Bool {
        let current = await center.notificationSettings()
        switch current.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            registerCategories()
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                // No `.badge`: the app never sets an icon badge (D8); the Payday tab badge is enough.
                let granted = try await center.requestAuthorization(options: [.alert, .sound])
                if granted { registerCategories() }
                return granted
            } catch {
                Self.logger.error("Authorization failed: \(error.localizedDescription, privacy: .public)")
                return false
            }
        @unknown default:
            return false
        }
    }

    func schedulePaydayReview(at date: Date, thawingCount: Int, total: Decimal) async {
        let content = UNMutableNotificationContent()
        content.title = ThawNotification.paydayTitle(count: thawingCount)
        content.body = ThawNotification.paydayBody(total: total, funMoney: funMoney)
        content.sound = .default
        content.categoryIdentifier = ThawNotification.paydayCategory
        await add(identifier: ThawNotification.paydayIdentifier, content: content, at: date)
    }

    func scheduleReminder(at date: Date, thawingCount: Int, total: Decimal) async {
        let content = UNMutableNotificationContent()
        content.title = ThawNotification.paydayTitle(count: thawingCount)
        content.body = ThawNotification.paydayBody(total: total, funMoney: funMoney)
        content.sound = .default
        content.categoryIdentifier = ThawNotification.paydayCategory
        await add(identifier: ThawNotification.reminderIdentifier, content: content, at: date)
    }

    func scheduleTimerThaw(wantID: UUID, name: String, at date: Date) async {
        let content = UNMutableNotificationContent()
        content.title = "\(name) has thawed."
        content.body = "Still on your mind? It's your call."
        content.sound = .default
        content.userInfo = [ThawNotification.wantIDKey: wantID.uuidString]
        await add(identifier: ThawNotification.timerPrefix + wantID.uuidString, content: content, at: date)
    }

    func pendingIdentifiers() async -> [String] {
        await center.pendingNotificationRequests().map(\.identifier)
    }

    func cancel(identifiers: [String]) async {
        guard !identifiers.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func logPending(context: String) async {
#if DEBUG
        let requests = await center.pendingNotificationRequests().sorted { $0.identifier < $1.identifier }
        Self.logger.notice("Pending after \(context, privacy: .public): \(requests.count, privacy: .public) request(s)")
        for request in requests {
            let fire = (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
            let when = fire.map { $0.formatted(.iso8601) } ?? "none"
            let id = request.identifier, content = request.content
            Self.logger.notice("Pending \(id, privacy: .public) at \(when, privacy: .public) category=\(content.categoryIdentifier, privacy: .public) title=\(content.title, privacy: .public) body=\(content.body, privacy: .public)")
        }
#endif
    }

    private func registerCategories() {
        let review = UNNotificationAction(identifier: ThawNotification.reviewNowAction,
                                          title: "Review now", options: [.foreground])
        let remind = UNNotificationAction(identifier: ThawNotification.remindTonightAction,
                                          title: "Remind me tonight", options: [])
        let category = UNNotificationCategory(identifier: ThawNotification.paydayCategory,
                                              actions: [review, remind], intentIdentifiers: [])
        center.setNotificationCategories([category])
    }

    private func add(identifier: String, content: UNMutableNotificationContent, at date: Date) async {
        guard date > .now else { return }
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        do {
            try await center.add(request)
        } catch {
            Self.logger.error("Schedule failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

/// Where a tapped notification should go.
nonisolated enum NotificationRoute: Equatable, Sendable {
    /// The Payday review (payday notification, its reminder, "Review now").
    case review
    /// A timer thaw: that want's "Still want it?", or Item detail once decided (D7).
    case want(UUID)

    /// The route for a notification response, or nil when the action needs no navigation ("Remind me tonight", dismiss).
    static func from(actionIdentifier: String, requestIdentifier: String,
                     userInfo: [AnyHashable: Any]) -> NotificationRoute? {
        switch actionIdentifier {
        case ThawNotification.reviewNowAction:
            return .review
        case UNNotificationDefaultActionIdentifier:
            if let id = timerWantID(requestIdentifier: requestIdentifier, userInfo: userInfo) { return .want(id) }
            return .review
        default:
            return nil
        }
    }

    /// The want id of a timer thaw, from `userInfo` or, for requests scheduled before it was added, the identifier.
    static func timerWantID(requestIdentifier: String, userInfo: [AnyHashable: Any]) -> UUID? {
        if let string = userInfo[ThawNotification.wantIDKey] as? String, let id = UUID(uuidString: string) { return id }
        guard requestIdentifier.hasPrefix(ThawNotification.timerPrefix) else { return nil }
        return UUID(uuidString: String(requestIdentifier.dropFirst(ThawNotification.timerPrefix.count)))
    }
}

enum NotificationReminder {
    /// 20:00 today, or one hour from now when it is already 20:00 or later.
    nonisolated static func tonightDate(now: Date, calendar: Calendar) -> Date {
        let tonight = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: now)
        if let tonight, tonight > now { return tonight }
        return now.addingTimeInterval(3600)
    }
}

nonisolated final class NotificationActionHandler: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    private let reminders: Reminders
    private let onRoute: @MainActor @Sendable (NotificationRoute) -> Void

    /// Fun money and counts are read from `reminders` when an action runs, never captured at launch.
    init(reminders: Reminders, onRoute: @escaping @MainActor @Sendable (NotificationRoute) -> Void) {
        self.reminders = reminders
        self.onRoute = onRoute
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let request = response.notification.request
        await handle(actionIdentifier: response.actionIdentifier, requestIdentifier: request.identifier,
                     userInfo: request.content.userInfo)
    }

    func handle(actionIdentifier: String, requestIdentifier: String, userInfo: [AnyHashable: Any]) async {
        if actionIdentifier == ThawNotification.remindTonightAction {
            await reminders.scheduleTonightReminder(requestingPermission: false)
            return
        }
        guard let route = NotificationRoute.from(actionIdentifier: actionIdentifier,
                                                 requestIdentifier: requestIdentifier, userInfo: userInfo) else { return }
        let onRoute = onRoute
        await MainActor.run { onRoute(route) }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
