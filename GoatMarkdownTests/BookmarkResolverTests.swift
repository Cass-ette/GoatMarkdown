import Foundation
import XCTest
@testable import GoatMarkdown

final class BookmarkResolverTests: XCTestCase {
    func testSignatureForBlockIsStableAndDistinctPerBlock() {
        let doc = MarkdownDocument(
            blocks: [
                .heading(level: 1, text: "Title"),
                .paragraph(text: "Hello world")
            ],
            rawText: ""
        )

        let sig0 = BookmarkResolver.signature(for: doc.blocks[0])
        let sig1 = BookmarkResolver.signature(for: doc.blocks[1])

        XCTAssertNotEqual(sig0, sig1)
        XCTAssertEqual(sig0, BookmarkResolver.signature(for: doc.blocks[0]))
    }

    func testResolverFindsBlockBySignatureAfterInsertion() {
        let original = MarkdownDocument(
            blocks: [
                .heading(level: 1, text: "Title"),
                .paragraph(text: "Target paragraph")
            ],
            rawText: ""
        )
        let targetSignature = BookmarkResolver.signature(for: original.blocks[1])

        let edited = MarkdownDocument(
            blocks: [
                .heading(level: 1, text: "Title"),
                .paragraph(text: "Newly inserted"),
                .paragraph(text: "Target paragraph")
            ],
            rawText: ""
        )

        let resolved = BookmarkResolver.resolveBlockIndex(
            signature: targetSignature,
            originalIndex: 1,
            in: edited
        )

        XCTAssertEqual(resolved, 2)
    }

    func testResolverFallsBackToOriginalIndexWhenSignatureMissing() {
        let edited = MarkdownDocument(
            blocks: [
                .heading(level: 1, text: "Title"),
                .paragraph(text: "Replacement paragraph")
            ],
            rawText: ""
        )

        let resolved = BookmarkResolver.resolveBlockIndex(
            signature: "missing-signature",
            originalIndex: 1,
            in: edited
        )

        XCTAssertEqual(resolved, 1)
    }

    func testResolverReturnsNilWhenIndexOutOfRangeAndSignatureMissing() {
        let edited = MarkdownDocument(
            blocks: [.heading(level: 1, text: "Title")],
            rawText: ""
        )

        let resolved = BookmarkResolver.resolveBlockIndex(
            signature: "missing",
            originalIndex: 5,
            in: edited
        )

        XCTAssertNil(resolved)
    }
}
