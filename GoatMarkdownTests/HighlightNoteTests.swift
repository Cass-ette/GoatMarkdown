import Foundation
import XCTest
@testable import GoatMarkdown

final class HighlightNoteTests: XCTestCase {
    func testHighlightDefaultsToNilNote() {
        let h = Highlight(blockIndex: 0, textIndex: 0, rangeStart: 0, rangeEnd: 5, color: .yellow)
        XCTAssertNil(h.note)
    }

    func testHighlightStoresNote() {
        let h = Highlight(blockIndex: 0, textIndex: 0, rangeStart: 0, rangeEnd: 5, color: .yellow, note: "test note")
        XCTAssertEqual(h.note, "test note")
    }

    func testHighlightNoteRoundTripsCodable() throws {
        let original = Highlight(blockIndex: 1, textIndex: 0, rangeStart: 3, rangeEnd: 8, color: .green, note: "important")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Highlight.self, from: data)
        XCTAssertEqual(decoded.note, "important")
    }

    func testHighlightWithoutNoteDecodesFromLegacyData() throws {
        // Simulates data from before the note field existed
        let legacy = Highlight(blockIndex: 0, textIndex: 0, rangeStart: 0, rangeEnd: 5, color: .yellow)
        let data = try JSONEncoder().encode(legacy)
        // Remove the note key to simulate truly legacy data
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        json.removeValue(forKey: "note")
        let legacyData = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(Highlight.self, from: legacyData)
        XCTAssertNil(decoded.note)
    }
}

final class MarkdownReaderStateNoteTests: XCTestCase {
    func testUpdateHighlightNotePersists() {
        let suiteName = "NoteIntegration-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let highlightStore = HighlightStore(defaults: defaults)
        let state = MarkdownReaderState(defaults: defaults, highlightStore: highlightStore)
        state.highlightState.add(Highlight(blockIndex: 0, textIndex: 0, rangeStart: 0, rangeEnd: 5, color: .yellow))

        let id = state.highlightState.highlights.first!.id
        state.updateHighlightNote(id: id, note: "persisted note")

        // Note should be in state
        XCTAssertEqual(state.highlightState.highlights.first?.note, "persisted note")
    }
}

final class HighlightStateNoteTests: XCTestCase {
    private var state: HighlightState!

    override func setUp() {
        super.setUp()
        state = HighlightState()
    }

    override func tearDown() {
        state = nil
        super.tearDown()
    }

    func testUpdateNoteOnExistingHighlight() {
        let h = Highlight(blockIndex: 0, textIndex: 0, rangeStart: 0, rangeEnd: 5, color: .yellow)
        state.add(h)
        state.updateNote(id: h.id, note: "my annotation")
        XCTAssertEqual(state.highlights.first?.note, "my annotation")
    }

    func testUpdateNoteToNilClearsNote() {
        let h = Highlight(blockIndex: 0, textIndex: 0, rangeStart: 0, rangeEnd: 5, color: .yellow, note: "old")
        state.add(h)
        state.updateNote(id: h.id, note: nil)
        XCTAssertNil(state.highlights.first?.note)
    }

    func testUpdateNoteOnNonexistentIDDoesNothing() {
        let h = Highlight(blockIndex: 0, textIndex: 0, rangeStart: 0, rangeEnd: 5, color: .yellow)
        state.add(h)
        state.updateNote(id: UUID(), note: "ghost")
        XCTAssertNil(state.highlights.first?.note)
    }
}
