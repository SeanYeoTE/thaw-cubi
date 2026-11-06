import XCTest
@testable import Thaw

final class PresenterShareItemParserTests: XCTestCase {
    private typealias Input = ShareItemParser.Input

    func testSafariStylePageTitleAndURL() {
        let url = URL(string: "https://www.example.com/p/brass-lamp?ref=1")!
        let result = ShareItemParser.parse(Input(contentText: "Brass Desk Lamp", urls: [url]))
        XCTAssertEqual(result, .init(name: "Brass Desk Lamp", link: url))
    }

    func testAttributedTitleWinsOverContentText() {
        let url = URL(string: "https://shop.test/x")!
        let result = ShareItemParser.parse(Input(title: "  Kettle\n Pro ", contentText: "Some description", urls: [url]))
        XCTAssertEqual(result.name, "Kettle Pro")
    }

    func testPlainTextContainingURL() {
        let result = ShareItemParser.parse(Input(texts: ["Look at this lamp https://example.com/lamp it's lovely"]))
        XCTAssertEqual(result.link, URL(string: "https://example.com/lamp"))
        XCTAssertEqual(result.name, "Look at this lamp it's lovely")
    }

    func testURLOnlyFallsBackToHumanisedPath() {
        let url = URL(string: "https://www.example.com/products/noise-cancelling_headphones.html")!
        let result = ShareItemParser.parse(Input(urls: [url]))
        XCTAssertEqual(result, .init(name: "Noise cancelling headphones", link: url))
    }

    func testURLAsTextFallsBackToHumanisedName() {
        let result = ShareItemParser.parse(Input(contentText: "https://example.com/brass-lamp"))
        XCTAssertEqual(result.link, URL(string: "https://example.com/brass-lamp"))
        XCTAssertEqual(result.name, "Brass lamp")
    }

    func testHumanisedSkipsNumericSegmentsAndFallsBackToHost() {
        XCTAssertEqual(ShareItemParser.humanised(URL(string: "https://www.example.com/lamp/12345")!), "Lamp")
        XCTAssertEqual(ShareItemParser.humanised(URL(string: "https://www.example.com/")!), "example.com")
        XCTAssertEqual(ShareItemParser.humanised(URL(string: "https://example.com")!), "example.com")
    }

    func testNonWebURLsAreIgnored() {
        let file = URL(fileURLWithPath: "/Users/me/notes.txt")
        let result = ShareItemParser.parse(Input(contentText: "Notes", urls: [file]))
        XCTAssertNil(result.link)
        XCTAssertEqual(result.name, "Notes")
    }

    func testPrefersWebURLAttachment() {
        let file = URL(fileURLWithPath: "/Users/me/a.txt"), web = URL(string: "http://example.com/a")!
        XCTAssertEqual(ShareItemParser.parse(Input(urls: [file, web])).link, web)
    }

    func testTextOnlyWithoutURL() {
        XCTAssertEqual(ShareItemParser.parse(Input(texts: ["Standing desk"])), .init(name: "Standing desk", link: nil))
    }

    func testEmptyInput() {
        XCTAssertEqual(ShareItemParser.parse(Input()), .init(name: "", link: nil))
    }

    func testLongNamesAreTruncated() {
        let name = ShareItemParser.parse(Input(title: String(repeating: "a", count: 300))).name
        XCTAssertEqual(name.count, ShareItemParser.maxNameLength)
        XCTAssertTrue(name.hasSuffix("…"))
    }

    func testLongProductTitlesAreShortened() {
        let title = "Sony WH-1000XM5 Wireless Noise Cancelling Headphones - 30hr Battery, Black | Amazon"
        let name = ShareItemParser.parse(Input(title: title)).name
        XCTAssertEqual(name, "Sony WH-1000XM5 Wireless Noise…")
        XCTAssertLessThanOrEqual(name.count, ShareItemParser.maxNameLength)
    }

    func testDisplayHostDropsWWW() {
        XCTAssertEqual(ShareItemParser.displayHost(URL(string: "https://www.example.com/x")!), "example.com")
        XCTAssertEqual(ShareItemParser.displayHost(URL(string: "https://shop.example.com")!), "shop.example.com")
    }
}
