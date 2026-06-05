import Foundation
import XCTest
@testable import GoatMarkdown

final class HighlightStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "HighlightStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testEmptyStoreReturnsEmpty() {
        let store = HighlightStore(defaults: defaults)
        XCTAssertEqual(store.highlights(for: "/tmp/A.md"), [])
    }

    func testSetHighlightsPersistsAcrossInstances() {
        let store = HighlightStore(defaults: defaults)
        let highlight = Highlight(
            blockIndex: 0,
            textIndex: 0,
            rangeStart: 5,
            rangeEnd: 10,
            color: .yellow
        )
        store.setHighlights([highlight], for: "/tmp/A.md")

        let reloaded = HighlightStore(defaults: defaults)
        XCTAssertEqual(reloaded.highlights(for: "/tmp/A.md"), [highlight])
    }

    func testSetEmptyHighlightsRemovesFileEntry() {
        let store = HighlightStore(defaults: defaults)
        store.setHighlights([Highlight(blockIndex: 0, textIndex: 0, rangeStart: 0, rangeEnd: 5, color: .green)], for: "/tmp/A.md")
        store.setHighlights([], for: "/tmp/A.md")

        XCTAssertEqual(store.highlights(for: "/tmp/A.md"), [])
    }

    func testCorruptedJSONStartsEmpty() {
        defaults.set(Data("not valid json".utf8), forKey: "highlights.byFilePath.v1")
        let store = HighlightStore(defaults: defaults)
        XCTAssertEqual(store.highlights(for: "/tmp/A.md"), [])
    }
}
