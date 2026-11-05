import XCTest
@testable import Thaw

final class BackendPersistenceTests: XCTestCase {
    private var directory: URL!
    private var fileURL: URL { directory.appendingPathComponent("state.json") }

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BackendPersistenceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func reload() -> WantStore { WantStore(fileURL: fileURL) }

    private func storeWithOne(price: Decimal = 120, link: URL? = nil) -> (WantStore, UUID) {
        let store = reload()
        store.save(settings: .default)
        store.add(name: "Lamp", price: price, reason: "Dark desk", link: link)
        return (store, store.wants[0].id)
    }

    private func draft(_ name: String = "Kettle", createdAt: Date = Date(timeIntervalSince1970: 1_790_000_000.25),
                       link: URL? = URL(string: "https://example.com/kettle")) -> SharedDraft {
        SharedDraft(id: UUID(), name: name, price: 45, reason: "Old one leaks", link: link, createdAt: createdAt)
    }

    // MARK: Decisions survive a reload

    func testSkipSurvivesReload() {
        let (store, id) = storeWithOne()
        store.update(id, status: .skipped)
        XCTAssertEqual(reload().want(id: id)?.status, .skipped)
    }

    func testBuySurvivesReload() {
        let (store, id) = storeWithOne()
        store.decide(id: id, keep: true)
        XCTAssertEqual(reload().want(id: id)?.status, .bought)
    }

    func testWaitSurvivesReload() {
        let (store, id) = storeWithOne()
        let before = store.want(id: id)!.thawsAt
        store.decide(id: id, keep: false)
        let after = store.want(id: id)!.thawsAt
        XCTAssertGreaterThan(after, before)
        let reloaded = reload().want(id: id)
        XCTAssertEqual(reloaded?.thawsAt, after)
        XCTAssertEqual(reloaded?.status, .cooling)
    }

    func testReopenSurvivesReloadAndKeepsThawsAt() {
        let (store, id) = storeWithOne()
        let thawsAt = store.want(id: id)!.thawsAt
        store.update(id, status: .skipped)
        reload().reopen(id)
        let reloaded = reload().want(id: id)
        XCTAssertEqual(reloaded?.status, .cooling)
        XCTAssertEqual(reloaded?.thawsAt, thawsAt)
    }

    func testReopenBoughtKeepsThawsAt() {
        let (store, id) = storeWithOne()
        let thawsAt = store.want(id: id)!.thawsAt
        store.decide(id: id, keep: true)
        store.reopen(id)
        XCTAssertEqual(store.want(id: id)?.status, .cooling)
        XCTAssertEqual(store.want(id: id)?.thawsAt, thawsAt)
        XCTAssertEqual(reload().want(id: id)?.thawsAt, thawsAt)
    }

    func testReopenOfCoolingWantIsNoOp() throws {
        let (store, id) = storeWithOne()
        let before = store.want(id: id)
        let data = try Data(contentsOf: fileURL)
        store.reopen(id)
        store.reopen(UUID())
        XCTAssertEqual(store.want(id: id), before)
        XCTAssertEqual(try Data(contentsOf: fileURL), data)
        XCTAssertEqual(reload().want(id: id), before)
    }

    func testSetDecisionSurvivesReload() {
        let (store, id) = storeWithOne()
        store.update(id, status: .skipped)
        store.setDecision(id, to: .bought)
        XCTAssertEqual(reload().want(id: id)?.status, .bought)
        let again = reload()
        again.setDecision(id, to: .skipped)
        XCTAssertEqual(reload().want(id: id)?.status, .skipped)
    }

    func testSetDecisionIgnoresCooling() {
        let (store, id) = storeWithOne()
        store.setDecision(id, to: .bought)
        XCTAssertEqual(reload().want(id: id)?.status, .cooling)
        store.update(id, status: .skipped)
        store.setDecision(id, to: .cooling)
        XCTAssertEqual(reload().want(id: id)?.status, .skipped)
    }

    func testDeleteSurvivesReload() {
        let (store, id) = storeWithOne()
        store.add(name: "Other", price: 10, reason: "")
        store.delete(id)
        let reloaded = reload()
        XCTAssertNil(reloaded.want(id: id))
        XCTAssertEqual(reloaded.wants.map(\.name), ["Other"])
    }

    func testEditSurvivesReload() {
        let (store, id) = storeWithOne()
        store.edit(id, name: "Floor lamp", price: 150, reason: "Brighter")
        let reloaded = reload().want(id: id)
        XCTAssertEqual(reloaded?.name, "Floor lamp")
        XCTAssertEqual(reloaded?.price, 150)
        XCTAssertEqual(reloaded?.reason, "Brighter")
    }

    func testAddWithLinkSurvivesReload() {
        let link = URL(string: "https://shop.example.com/lamp?id=3")!
        let frozenOn = Date(timeIntervalSince1970: 1_790_000_000)
        let store = reload()
        store.add(name: "Lamp", price: 12.345, reason: "Dark", link: link, frozenOn: frozenOn)
        let reloaded = reload().wants.first
        XCTAssertEqual(reloaded?.link, link)
        XCTAssertEqual(reloaded?.frozenOn, frozenOn)
        XCTAssertEqual(reloaded?.price, Decimal(string: "12.35"))
        XCTAssertEqual(reloaded?.status, .cooling)
    }

    // MARK: Compatibility

    func testOldJSONWithoutLinkDecodes() throws {
        let id = UUID()
        let json = """
        {"wants":[{"id":"\(id.uuidString)","name":"Old","price":20,"reason":"r","frozenOn":800000000,
        "progress":0,"status":"skipped","thawsAt":800100000}],
        "settings":{"rule":{"sameDate":{"day":15}},"reviewHour":8,"reviewMinute":30,"funMoney":200,
        "timerThreshold":30,"timerDays":2}}
        """
        try Data(json.utf8).write(to: fileURL)
        let store = reload()
        XCTAssertEqual(store.wants.count, 1)
        XCTAssertEqual(store.want(id: id)?.name, "Old")
        XCTAssertNil(store.want(id: id)?.link)
        XCTAssertEqual(store.want(id: id)?.status, .skipped)
        XCTAssertEqual(store.settings?.rule, .sameDate(day: 15))
        XCTAssertEqual(store.ingestedDraftIDs, [])
        store.reopen(id)
        XCTAssertEqual(reload().want(id: id)?.status, .cooling)
    }

    func testSettingsSurviveReload() {
        var settings = PaydaySettings.default
        settings.rule = .twiceMonthly(first: 1, second: 15)
        settings.reviewHour = 20
        settings.funMoney = 450
        reload().save(settings: settings)
        XCTAssertEqual(reload().settings, settings)
    }

    func testCorruptFileLoadsEmpty() throws {
        try Data("{not json".utf8).write(to: fileURL)
        let store = reload()
        XCTAssertTrue(store.wants.isEmpty)
        XCTAssertNil(store.settings)
        store.add(name: "Fresh", price: 5, reason: "")
        XCTAssertEqual(reload().wants.map(\.name), ["Fresh"])
    }

    // MARK: Share inbox and ingest

    func testInboxAppendPendingIngestRemove() throws {
        let inbox = ShareInbox(directory: directory.appendingPathComponent("group", isDirectory: true))
        XCTAssertEqual(inbox.pending(), [])
        let first = draft("Kettle")
        let second = draft("Toaster", link: nil)
        try inbox.append(first)
        try inbox.append(second)
        try inbox.append(first)
        XCTAssertEqual(inbox.pending(), [first, second])

        let store = reload()
        store.save(settings: .default)
        XCTAssertEqual(store.ingest(inbox.pending()), 2)
        inbox.remove(ids: [first.id, second.id])
        XCTAssertEqual(inbox.pending(), [])

        let reloaded = reload()
        XCTAssertEqual(Set(reloaded.cooling.map(\.name)), ["Kettle", "Toaster"])
        XCTAssertEqual(reloaded.cooling.first { $0.name == "Kettle" }?.link, first.link)
        XCTAssertEqual(Set(reloaded.ingestedDraftIDs), [first.id, second.id])
    }

    func testInboxRemoveKeepsOthers() throws {
        let inbox = ShareInbox(directory: directory)
        let first = draft("A"), second = draft("B")
        try inbox.append(first)
        try inbox.append(second)
        inbox.remove(ids: [first.id])
        XCTAssertEqual(ShareInbox(directory: directory).pending(), [second])
    }

    func testInboxWithoutContainerIsNoOp() throws {
        let inbox = ShareInbox(directory: nil)
        XCTAssertNil(inbox.fileURL)
        try inbox.append(draft())
        XCTAssertEqual(inbox.pending(), [])
        inbox.remove(ids: [UUID()])
    }

    func testIngestIsIdempotentAcrossReloads() {
        let drafts = [draft("A"), draft("B")]
        XCTAssertEqual(reload().ingest(drafts), 2)
        XCTAssertEqual(reload().ingest(drafts), 0)
        let more = drafts + [draft("C")]
        XCTAssertEqual(reload().ingest(more), 1)
        XCTAssertEqual(reload().wants.count, 3)
    }

    func testIngestDeduplicatesWithinOneBatch() {
        let one = draft()
        XCTAssertEqual(reload().ingest([one, one]), 1)
        XCTAssertEqual(reload().wants.count, 1)
    }

    func testIngestedDraftKeepsCreatedAtAsFrozenOn() {
        let settings = PaydaySettings.default
        let createdAt = Date(timeIntervalSince1970: 1_790_000_000.25)
        let cheap = SharedDraft(id: UUID(), name: "Cheap", price: 10, reason: "", link: nil, createdAt: createdAt)
        let pricey = SharedDraft(id: UUID(), name: "Pricey", price: 100, reason: "", link: nil, createdAt: createdAt)
        let store = reload()
        store.save(settings: settings)
        store.ingest([cheap, pricey])
        let reloaded = reload()
        let cheapWant = reloaded.wants.first { $0.name == "Cheap" }!
        let priceyWant = reloaded.wants.first { $0.name == "Pricey" }!
        XCTAssertEqual(cheapWant.frozenOn, createdAt)
        XCTAssertEqual(priceyWant.frozenOn, createdAt)
        XCTAssertEqual(cheapWant.status, .cooling)
        XCTAssertEqual(cheapWant.thawsAt,
                       Calendar.current.date(byAdding: .day, value: settings.timerDays, to: createdAt))
        XCTAssertEqual(priceyWant.thawsAt, settings.nextPayday(after: createdAt, calendar: .current))
    }

    func testIngestedDraftIDsAreCapped() {
        let drafts = (0..<(WantStore.ingestedDraftIDLimit + 5)).map { draft("D\($0)") }
        XCTAssertEqual(reload().ingest(drafts), drafts.count)
        let ids = reload().ingestedDraftIDs
        XCTAssertEqual(ids.count, WantStore.ingestedDraftIDLimit)
        XCTAssertEqual(ids, Array(drafts.suffix(WantStore.ingestedDraftIDLimit).map(\.id)))
    }
}
