import Foundation
import XCTest
@testable import GoatMarkdown

final class MarkdownParserTests: XCTestCase {
    func testParsesHeadings() throws {
        let document = MarkdownParser.parse("# Title\n## Subtitle\n### Deep")
        XCTAssertEqual(document.blocks.count, 3)
        XCTAssertEqual(document.blocks[0], .heading(level: 1, text: "Title"))
        XCTAssertEqual(document.blocks[1], .heading(level: 2, text: "Subtitle"))
        XCTAssertEqual(document.blocks[2], .heading(level: 3, text: "Deep"))
    }

    func testParsesParagraphs() throws {
        let document = MarkdownParser.parse("Hello world\n\nSecond paragraph")
        XCTAssertEqual(document.blocks.count, 2)
        XCTAssertEqual(document.blocks[0], .paragraph(text: "Hello world"))
        XCTAssertEqual(document.blocks[1], .paragraph(text: "Second paragraph"))
    }

    func testParsesUnorderedList() throws {
        let document = MarkdownParser.parse("- one\n- two\n- three")
        XCTAssertEqual(document.blocks.count, 1)
        XCTAssertEqual(document.blocks[0], .unorderedList(items: ["one", "two", "three"]))
    }

    func testParsesOrderedList() throws {
        let document = MarkdownParser.parse("1. first\n2. second")
        XCTAssertEqual(document.blocks.count, 1)
        XCTAssertEqual(document.blocks[0], .orderedList(items: ["first", "second"]))
    }

    func testParsesBlockquote() throws {
        let document = MarkdownParser.parse("> quoted text")
        XCTAssertEqual(document.blocks.count, 1)
        XCTAssertEqual(document.blocks[0], .blockquote(text: "quoted text"))
    }

    func testParsesFencedCodeBlock() throws {
        let input = "```swift\nlet x = 1\n```"
        let document = MarkdownParser.parse(input)
        XCTAssertEqual(document.blocks.count, 1)
        XCTAssertEqual(document.blocks[0], .codeBlock(language: "swift", code: "let x = 1"))
    }

    func testParsesThematicBreak() throws {
        let document = MarkdownParser.parse("---")
        XCTAssertEqual(document.blocks.count, 1)
        XCTAssertEqual(document.blocks[0], .thematicBreak)
    }

    func testParsesMixedDocument() throws {
        let input = """
        # Title

        Some text

        - item

        ---

        > quote
        """
        let document = MarkdownParser.parse(input)
        XCTAssertEqual(document.blocks.count, 5)
        XCTAssertEqual(document.blocks[0], .heading(level: 1, text: "Title"))
        XCTAssertEqual(document.blocks[1], .paragraph(text: "Some text"))
        XCTAssertEqual(document.blocks[2], .unorderedList(items: ["item"]))
        XCTAssertEqual(document.blocks[3], .thematicBreak)
        XCTAssertEqual(document.blocks[4], .blockquote(text: "quote"))
    }

    // MARK: - Table

    func testParsesTable() throws {
        let input = """
        | Name | Age |
        |------|-----|
        | Alice | 30 |
        | Bob | 25 |
        """
        let document = MarkdownParser.parse(input)
        XCTAssertEqual(document.blocks.count, 1)
        guard case .table(let headers, let alignments, let rows) = document.blocks[0] else {
            XCTFail("Expected table block")
            return
        }
        XCTAssertEqual(headers, ["Name", "Age"])
        XCTAssertEqual(alignments, [.left, .left])
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0], ["Alice", "30"])
        XCTAssertEqual(rows[1], ["Bob", "25"])
    }

    func testParsesTableWithAlignment() throws {
        let input = """
        | Left | Center | Right |
        |:-----|:------:|------:|
        | a | b | c |
        """
        let document = MarkdownParser.parse(input)
        XCTAssertEqual(document.blocks.count, 1)
        guard case .table(_, let alignments, _) = document.blocks[0] else {
            XCTFail("Expected table block")
            return
        }
        XCTAssertEqual(alignments, [.left, .center, .right])
    }

    // MARK: - Image

    func testParsesImage() throws {
        let document = MarkdownParser.parse("![alt text](image.png)")
        XCTAssertEqual(document.blocks.count, 1)
        XCTAssertEqual(document.blocks[0], .image(alt: "alt text", url: "image.png"))
    }

    // MARK: - Standalone link

    func testParsesStandaloneLink() throws {
        let document = MarkdownParser.parse("[Goat](https://example.com)")
        XCTAssertEqual(document.blocks.count, 1)
        XCTAssertEqual(document.blocks[0], .link(text: "Goat", url: "https://example.com"))
    }
}
