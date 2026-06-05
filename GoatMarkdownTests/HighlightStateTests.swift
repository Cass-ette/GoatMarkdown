import Foundation
import XCTest
@testable import GoatMarkdown

final class HighlightStateTests: XCTestCase {
    private var state: HighlightState!

    override func setUp() {
        super.setUp()
        state = HighlightState()
    }

    override func tearDown() {
        state = nil
        super.tearDown()
    }

    func testAddAppendsHighlight() {
        let h = Highlight(blockIndex: 0, textIndex: 0, rangeStart: 0, rangeEnd: 5, color: .yellow)
        state.add(h)
        XCTAssertEqual(state.highlights, [h])
    }

    func testAddWithSameIDReplaces() {
        let id = UUID()
        let first = Highlight(id: id, blockIndex: 0, textIndex: 0, rangeStart: 0, rangeEnd: 5, color: .yellow)
        let second = Highlight(id: id, blockIndex: 1, textIndex: 0, rangeStart: 0, rangeEnd: 5, color: .blue)
        state.add(first)
        state.add(second)
        XCTAssertEqual(state.highlights.count, 1)
        XCTAssertEqual(state.highlights.first, second)
    }

    func testRemoveDeletesByID() {
        let h = Highlight(blockIndex: 0, textIndex: 0, rangeStart: 0, rangeEnd: 5, color: .yellow)
        state.add(h)
        state.remove(id: h.id)
        XCTAssertTrue(state.highlights.isEmpty)
    }

    func testFindReturnsOverlappingHighlight() {
        let h = Highlight(blockIndex: 0, textIndex: 0, rangeStart: 5, rangeEnd: 15, color: .yellow)
        state.add(h)
        let found = state.find(blockIndex: 0, textIndex: 0, range: 10..<12)
        XCTAssertEqual(found?.id, h.id)
    }

    func testFindReturnsNilForNonOverlapping() {
        state.add(Highlight(blockIndex: 0, textIndex: 0, rangeStart: 5, rangeEnd: 15, color: .yellow))
        XCTAssertNil(state.find(blockIndex: 0, textIndex: 0, range: 20..<25))
    }

    func testFindDistinguishesByTextIndex() {
        let h = Highlight(blockIndex: 0, textIndex: 0, rangeStart: 0, rangeEnd: 10, color: .yellow)
        state.add(h)
        XCTAssertNil(state.find(blockIndex: 0, textIndex: 1, range: 0..<5))
    }

    func testToggleAddsWhenNoExisting() {
        let result = state.toggle(blockIndex: 0, textIndex: 0, range: 0..<5)
        XCTAssertNotNil(result)
        XCTAssertEqual(state.highlights.count, 1)
    }

    func testToggleRemovesWhenExisting() {
        _ = state.toggle(blockIndex: 0, textIndex: 0, range: 0..<5)
        let result = state.toggle(blockIndex: 0, textIndex: 0, range: 0..<5)
        XCTAssertNil(result)
        XCTAssertTrue(state.highlights.isEmpty)
    }

    func testHighlightsInBlockFiltersByBothIndices() {
        state.add(Highlight(blockIndex: 0, textIndex: 0, rangeStart: 0, rangeEnd: 5, color: .yellow))
        state.add(Highlight(blockIndex: 0, textIndex: 1, rangeStart: 0, rangeEnd: 5, color: .green))
        XCTAssertEqual(state.highlights(in: 0, textIndex: 0).count, 1)
        XCTAssertEqual(state.highlights(in: 0, textIndex: 1).count, 1)
        XCTAssertEqual(state.highlights(in: 0, textIndex: 2).count, 0)
    }

    func testLoadReplacesAll() {
        state.add(Highlight(blockIndex: 0, textIndex: 0, rangeStart: 0, rangeEnd: 5, color: .yellow))
        let replacement = [Highlight(blockIndex: 1, textIndex: 0, rangeStart: 0, rangeEnd: 5, color: .blue)]
        state.load(replacement)
        XCTAssertEqual(state.highlights, replacement)
    }
}
