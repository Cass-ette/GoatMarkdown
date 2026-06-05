import Foundation
import SwiftUI
import XCTest
@testable import GoatMarkdown

@MainActor
final class HighlightRenderingLogicTests: XCTestCase {
    func testRenderedPlainTextStripsMarkdownSyntax() {
        let text = "**bold** text"
        let attributed = (try? AttributedString(markdown: text)) ?? AttributedString(text)
        XCTAssertEqual(String(attributed.characters), "bold text")
    }

    func testApplyHighlightsUsesRenderedOffsetsForInlineMarkdown() {
        // Paragraph "**bold** text" renders to "bold text" (9 chars).
        // A highlight on "bold" should be at rendered offsets 0..<4, not raw offsets 2..<6.
        let document = MarkdownDocument(blocks: [.paragraph(text: "**bold** text")], rawText: "")
        let state = HighlightState()
        state.add(Highlight(blockIndex: 0, textIndex: 0, rangeStart: 0, rangeEnd: 4, color: .yellow))

        let renderer = MarkdownRenderer(document: document, highlightState: state)
        let attributed = renderer.renderAttributedStringForTesting(text: "**bold** text", blockIndex: 0, textIndex: 0)
        let background = backgroundColorRange(in: attributed)
        XCTAssertEqual(background?.lowerBound, 0)
        XCTAssertEqual(background?.upperBound, 4)
    }

    func testApplyHighlightsIgnoresOutOfRangeOffsets() {
        // Stale highlight with rangeEnd > rendered length should be skipped (not crash, not apply wrong).
        let document = MarkdownDocument(blocks: [.paragraph(text: "short")], rawText: "")
        let state = HighlightState()
        state.add(Highlight(blockIndex: 0, textIndex: 0, rangeStart: 0, rangeEnd: 100, color: .yellow))

        let renderer = MarkdownRenderer(document: document, highlightState: state)
        let attributed = renderer.renderAttributedStringForTesting(text: "short", blockIndex: 0, textIndex: 0)
        let count = attributed.runs.filter { $0.backgroundColor != nil }.count
        XCTAssertEqual(count, 0)
    }

    func testApplyHighlightsRespectsTextIndexScope() {
        // List with two items, each its own textIndex. Highlight on item 0 must not affect item 1.
        let document = MarkdownDocument(
            blocks: [.unorderedList(items: ["alpha", "beta"])],
            rawText: ""
        )
        let state = HighlightState()
        state.add(Highlight(blockIndex: 0, textIndex: 0, rangeStart: 0, rangeEnd: 5, color: .yellow))

        let renderer = MarkdownRenderer(document: document, highlightState: state)
        let alphaAttributed = renderer.renderAttributedStringForTesting(text: "alpha", blockIndex: 0, textIndex: 0)
        let betaAttributed = renderer.renderAttributedStringForTesting(text: "beta", blockIndex: 0, textIndex: 1)

        XCTAssertNotNil(backgroundColorRange(in: alphaAttributed))
        XCTAssertNil(backgroundColorRange(in: betaAttributed))
    }

    private func backgroundColorRange(in attributed: AttributedString) -> Range<Int>? {
        var lower: Int? = nil
        var upper: Int? = nil
        let chars = attributed.characters
        for run in attributed.runs {
            guard run.backgroundColor != nil else { continue }
            let start = chars.distance(from: chars.startIndex, to: run.range.lowerBound)
            let end = chars.distance(from: chars.startIndex, to: run.range.upperBound)
            if lower == nil { lower = start }
            upper = end
        }
        guard let l = lower, let u = upper else { return nil }
        return l..<u
    }
}
