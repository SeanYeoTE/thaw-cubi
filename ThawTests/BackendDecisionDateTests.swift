import XCTest
@testable import Thaw

final class BackendDecisionDateTests: XCTestCase {
    private var directory: URL!
    private var fileURL: URL { directory.appendingPathComponent("state.json") }
    private let decidedAt = Date(timeIntervalSince1970: 1_790_000_000)

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BackendDecisionDateTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func reload() -> WantStore { WantStore(fileURL: fileURL) }

    private func storeWithOne() -> (WantStore, UUID) {
        let store = reload()
        store.save(settings: .default)
        store.add(name: "Lamp", price: 120, reason: "Dark desk")
        return (store, store.wants[0].id)
    }

    // MARK: Old data

    func testOldWantWithoutDecidedOnDecodes() throws {
        let id = UUID()
        let json = """
        {"id":"\(id.uuidString)","name":"Lamp","price":120,"reason":"Dark desk","frozenOn":800000000,
         "progress":1,"status":"skipped","thawsAt":810000000}
        """
        let want = try JSONDecoder().decode(Want.self, from: Data(json.utf8))
        XCTAssertEqual(want.id, id)
        XCTAssertNil(want.decidedOn)
        XCTAssertEqual(want.decisionDate, want.thawsAt)
        XCTAssertEqual(want.thawsAt, Date(timeIntervalSinceReferenceDate: 810_000_000))
    }

    func testOldStateFileWithoutDecidedOnLoads() throws {
        let json = """
        {"wants":[{"id":"\(UUID().uuidString)","name":"Lamp","price":120,"reason":"Dark desk",
         "frozenOn":800000000,"progress":1,"status":"bought","thawsAt":810000000}]}
        """
        try Data(json.utf8).write(to: fileURL)
        let store = reload()
        XCTAssertEqual(store.wants.count, 1)
        XCTAssertNil(store.wants[0].decidedOn)
        XCTAssertEqual(store.wants[0].decisionDate, store.wants[0].thawsAt)
    }

    // MARK: Persistence

    func testDecidedOnSurvivesReload() {
        let (store, id) = storeWithOne()
        store.update(id, status: .skipped, now: decidedAt)
        XCTAssertEqual(reload().want(id: id)?.decidedOn, decidedAt)
    }

    // MARK: Paths

    func testBuyAtPaydaySetsDecidedOn() {
        let (store, id) = storeWithOne()
        store.decide(id: id, keep: true, now: decidedAt)
        XCTAssertEqual(store.want(id: id)?.status, .bought)
        XCTAssertEqual(store.want(id: id)?.decidedOn, decidedAt)
    }

    func testWaitLeavesDecidedOnNil() {
        let (store, id) = storeWithOne()
        store.decide(id: id, keep: false, now: decidedAt)
        XCTAssertEqual(store.want(id: id)?.status, .cooling)
        XCTAssertNil(store.want(id: id)?.decidedOn)
    }

    func testUpdateToSkippedSetsDecidedOn() {
        let (store, id) = storeWithOne()
        store.update(id, status: .skipped, now: decidedAt)
        XCTAssertEqual(store.want(id: id)?.decidedOn, decidedAt)
        XCTAssertEqual(store.want(id: id)?.decisionDate, decidedAt)
    }

    func testUpdateToCoolingClearsDecidedOn() {
        let (store, id) = storeWithOne()
        store.update(id, status: .bought, now: decidedAt)
        store.update(id, status: .cooling, now: decidedAt.addingTimeInterval(60))
        XCTAssertNil(store.want(id: id)?.decidedOn)
    }

    func testUpdateBetweenDecisionsKeepsDecidedOn() {
        let (store, id) = storeWithOne()
        store.update(id, status: .skipped, now: decidedAt)
        store.update(id, status: .bought, now: decidedAt.addingTimeInterval(86_400))
        XCTAssertEqual(store.want(id: id)?.decidedOn, decidedAt)
    }

    func testReopenClearsDecidedOn() {
        let (store, id) = storeWithOne()
        store.update(id, status: .skipped, now: decidedAt)
        store.reopen(id)
        XCTAssertEqual(store.want(id: id)?.status, .cooling)
        XCTAssertNil(store.want(id: id)?.decidedOn)
        XCTAssertNil(reload().want(id: id)?.decidedOn)
    }

    func testSetDecisionKeepsOriginalDate() {
        let (store, id) = storeWithOne()
        store.update(id, status: .skipped, now: decidedAt)
        store.setDecision(id, to: .bought)
        XCTAssertEqual(store.want(id: id)?.status, .bought)
        XCTAssertEqual(store.want(id: id)?.decidedOn, decidedAt)
    }

    func testEditKeepsDecidedOn() {
        let (store, id) = storeWithOne()
        store.update(id, status: .skipped, now: decidedAt)
        store.edit(id, name: "Desk lamp", price: 10, reason: "Dark desk")
        XCTAssertEqual(store.want(id: id)?.decidedOn, decidedAt)
    }

    func testFixtureHistoryDecidedOnMatchesThawsAt() {
        for want in WantStore.fixtureHistory() {
            XCTAssertEqual(want.decidedOn, want.thawsAt)
        }
    }

    // MARK: Streak

    func testEarlySkipCountsInMonthDecided() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: 12))!
        let frozenOn = calendar.date(byAdding: .month, value: -3, to: now)!
        let thawsAt = calendar.date(byAdding: .month, value: 1, to: now)!
        let want = Want(id: UUID(), name: "Lamp", price: 120, reason: "", frozenOn: frozenOn, progress: 1,
                        status: .skipped, thawsAt: thawsAt, decidedOn: now)
        let stats = ProgressStats.make(wants: [want], funMoney: 300, now: now, calendar: calendar)
        XCTAssertEqual(stats.streak, 1)
    }
}
