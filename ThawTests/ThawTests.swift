import XCTest
@testable import Thaw

final class ThawTests: XCTestCase {
    @MainActor
    func testFixtureCoolingSplitsTimerAndPayday() {
        let store = WantStore(wants: WantStore.fixtureWants(), payday: WantStore.fixturePayday())
        XCTAssertEqual(store.cooling.count, 4)
        let timer = store.cooling.filter { $0.isUnderTimerThreshold }.map(\.name)
        XCTAssertEqual(timer, ["Phone case"])
        let thawing = store.cooling.filter { !$0.isUnderTimerThreshold }
        XCTAssertEqual(thawing.reduce(Decimal(0)) { $0 + $1.price }, 678)
    }

    @MainActor
    func testUpdateMovesWantOutOfCooling() {
        let store = WantStore(wants: WantStore.fixtureWants(), payday: WantStore.fixturePayday())
        let id = store.cooling[1].id
        store.update(id, status: .skipped)
        XCTAssertEqual(store.cooling.count, 3)
        XCTAssertEqual(store.saved.map(\.id), [id])
        XCTAssertEqual(store.want(id: id)?.status, .skipped)
    }

    @MainActor
    func testAddRoundsPriceAndStartsCooling() {
        let store = WantStore(wants: [], payday: WantStore.fixturePayday())
        store.add(name: "Desk lamp", price: Decimal(string: "29.999")!, reason: "Dim light")
        XCTAssertEqual(store.cooling.first?.name, "Desk lamp")
        XCTAssertEqual(store.cooling.first?.price, Decimal(string: "30.00"))
        XCTAssertTrue(store.cooling.first?.isUnderTimerThreshold == false)
    }

    @MainActor
    func testFormattingSingaporeDollars() {
        XCTAssertEqual(Formatting.sgd(189), "S$189")
        XCTAssertEqual(Formatting.sgd(1262), "S$1,262")
    }

    @MainActor
    func testPaydayDaysNeverNegativeWhenInFuture() {
        let future = Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now
        let schedule = PaydaySchedule(nextPayday: future, funMoney: 300)
        XCTAssertEqual(schedule.daysUntilNext, 3)
    }
}
