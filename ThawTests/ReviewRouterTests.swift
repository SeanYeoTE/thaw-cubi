import XCTest
import UserNotifications
@testable import Thaw

@MainActor
final class ReviewRouterTests: XCTestCase {
    private let now = Date.now

    private func want(_ name: String, _ price: Decimal, thawsIn days: Double, status: Want.Status = .cooling) -> Want {
        Want(id: UUID(), name: name, price: price, reason: "", frozenOn: now.addingTimeInterval(-86_400 * 3),
             progress: 0.5, status: status, thawsAt: now.addingTimeInterval(86_400 * days))
    }

    private func makeStore(_ wants: [Want]) -> WantStore {
        WantStore(wants: wants, payday: PaydaySchedule(nextPayday: now.addingTimeInterval(86_400 * 10), funMoney: 300))
    }

    private func route(_ action: String, id: String = ThawNotification.paydayIdentifier,
                       userInfo: [AnyHashable: Any] = [:]) -> NotificationRoute? {
        NotificationRoute.from(actionIdentifier: action, requestIdentifier: id, userInfo: userInfo)
    }

    // MARK: Response -> route

    func testPaydayTapAndReviewNowOpenTheReview() {
        XCTAssertEqual(route(UNNotificationDefaultActionIdentifier), .review)
        XCTAssertEqual(route(ThawNotification.reviewNowAction), .review)
        XCTAssertEqual(route(UNNotificationDefaultActionIdentifier, id: ThawNotification.reminderIdentifier), .review)
    }

    func testRemindTonightAndDismissDoNotNavigate() {
        XCTAssertNil(route(ThawNotification.remindTonightAction))
        XCTAssertNil(route(UNNotificationDismissActionIdentifier))
    }

    func testTimerTapRoutesToItsWantFromUserInfoOrIdentifier() {
        let id = UUID()
        XCTAssertEqual(route(UNNotificationDefaultActionIdentifier, id: ThawNotification.timerPrefix + id.uuidString,
                             userInfo: [ThawNotification.wantIDKey: id.uuidString]), .want(id))
        XCTAssertEqual(route(UNNotificationDefaultActionIdentifier, id: ThawNotification.timerPrefix + id.uuidString),
                       .want(id), "requests scheduled before userInfo existed still route by identifier")
        XCTAssertEqual(route(UNNotificationDefaultActionIdentifier, id: ThawNotification.timerPrefix + "junk"), .review)
    }

    // MARK: Route -> destination

    func testReviewRouteOpensTheQueueOrSaysNothingToReview() {
        let lamp = want("Lamp", 120, thawsIn: 5)
        XCTAssertEqual(ReviewDestination.resolve(.review, store: makeStore([lamp]), now: now), .review([lamp]))
        let decided = want("Old", 90, thawsIn: -1, status: .skipped)
        XCTAssertEqual(ReviewDestination.resolve(.review, store: makeStore([decided]), now: now), .nothingToReview)
    }

    func testThawedTimerWantOpensStillWantIt() {
        let socks = want("Socks", 12, thawsIn: -0.1)
        XCTAssertEqual(ReviewDestination.resolve(.want(socks.id), store: makeStore([socks]), now: now), .stillWantIt(socks))
    }

    func testDecidedOrWaitingWantOpensItemDetail() {
        let bought = want("Socks", 12, thawsIn: -1, status: .bought)
        let skipped = want("Pen", 8, thawsIn: -1, status: .skipped)
        let waited = want("Cap", 20, thawsIn: 10)
        let store = makeStore([bought, skipped, waited])
        XCTAssertEqual(ReviewDestination.resolve(.want(bought.id), store: store, now: now), .itemDetail(bought.id))
        XCTAssertEqual(ReviewDestination.resolve(.want(skipped.id), store: store, now: now), .itemDetail(skipped.id))
        XCTAssertEqual(ReviewDestination.resolve(.want(waited.id), store: store, now: now), .itemDetail(waited.id))
    }

    func testDeletedWantFallsBackToTheReview() {
        let lamp = want("Lamp", 120, thawsIn: 5)
        XCTAssertEqual(ReviewDestination.resolve(.want(UUID()), store: makeStore([lamp]), now: now), .review([lamp]))
        XCTAssertEqual(ReviewDestination.resolve(.want(UUID()), store: makeStore([]), now: now), .nothingToReview)
    }

    // MARK: Pending until the tabs exist

    func testRouteIsHeldUntilTabsAreReadyThenTakenOnce() {
        var pending = PendingRoute()
        XCTAssertNil(pending.take(isReady: true))
        pending.request(.review)
        XCTAssertNil(pending.take(isReady: false), "cold launch or onboarding: hold the request")
        XCTAssertEqual(pending.route, .review)
        XCTAssertEqual(pending.take(isReady: true), .review)
        XCTAssertNil(pending.take(isReady: true), "presented once only")
    }

    func testLatestRequestWins() {
        var pending = PendingRoute()
        let id = UUID()
        pending.request(.review)
        pending.request(.want(id))
        XCTAssertEqual(pending.take(isReady: true), .want(id))
    }
}
