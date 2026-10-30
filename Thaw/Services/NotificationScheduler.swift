import Foundation
import UserNotifications
import os

protocol NotificationScheduling: Sendable {
    func requestAuthorizationIfNeeded() async -> Bool
    func schedulePaydayReview(at: Date, thawingCount: Int, total: Decimal) async
    func scheduleTimerThaw(wantID: UUID, name: String, at: Date) async
    func scheduleReminder(at: Date, thawingCount: Int, total: Decimal) async
    func cancelAll() async
}

nonisolated enum ThawNotification {
    static let paydayCategory = "thaw.payday"
    static let reviewNowAction = "thaw.reviewNow"
    static let remindTonightAction = "thaw.remindTonight"
    static let paydayIdentifier = "thaw.payday.review"
    static let reminderIdentifier = "thaw.payday.reminder"
    static let timerPrefix = "thaw.timer."

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
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
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
        await add(identifier: ThawNotification.timerPrefix + wantID.uuidString, content: content, at: date)
    }

    func cancelAll() async {
        center.removeAllPendingNotificationRequests()
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

nonisolated enum NotificationRoute: Equatable, Sendable { case review }

enum NotificationReminder {
    /// 20:00 today, or one hour from now when it is already 20:00 or later.
    nonisolated static func tonightDate(now: Date, calendar: Calendar) -> Date {
        let tonight = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: now)
        if let tonight, tonight > now { return tonight }
        return now.addingTimeInterval(3600)
    }
}

nonisolated final class NotificationActionHandler: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    private let scheduler: any NotificationScheduling
    private let store: WantStore
    private let onRoute: @MainActor @Sendable (NotificationRoute) -> Void

    init(scheduler: any NotificationScheduling, store: WantStore,
         onRoute: @escaping @MainActor @Sendable (NotificationRoute) -> Void) {
        self.scheduler = scheduler
        self.store = store
        self.onRoute = onRoute
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier, ThawNotification.reviewNowAction:
            let route = onRoute
            await MainActor.run { route(.review) }
        case ThawNotification.remindTonightAction:
            let thawed = store.thawedWants
            let total = thawed.reduce(Decimal(0)) { $0 + $1.price }
            let date = NotificationReminder.tonightDate(now: .now, calendar: .current)
            await scheduler.scheduleReminder(at: date, thawingCount: thawed.count, total: total)
        default:
            break
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
