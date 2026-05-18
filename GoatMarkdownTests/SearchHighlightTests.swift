import AppKit
import CoreGraphics
import SwiftUI
import XCTest
@testable import GoatMarkdown

@MainActor
final class SearchHighlightTests: XCTestCase {
    func testOnlyCurrentSearchMatchUsesSolidHighlightColor() throws {
        let sanityCheckPixels = try solidOrangePixelCount(in: highlightedText("go"))
        let singleMatchPixels = try solidOrangePixelCount(for: "go")
        let repeatedMatchPixels = try solidOrangePixelCount(for: "go go")

        XCTAssertGreaterThan(sanityCheckPixels, 0)
        XCTAssertGreaterThan(singleMatchPixels, 0)
        XCTAssertLessThan(
            repeatedMatchPixels,
            Int(Double(singleMatchPixels) * 1.35),
            "Expected repeated matches to have only one solid current highlight; single=\(singleMatchPixels), repeated=\(repeatedMatchPixels)"
        )
    }

    func testCurrentInlineMarkdownMatchUsesSolidHighlightColor() throws {
        let inlinePixels = try solidOrangePixelCount(for: "**yak**", query: "yak")

        XCTAssertGreaterThan(inlinePixels, 0)
    }

    func testCurrentTableHeaderMatchUsesSolidHighlightColor() throws {
        let document = MarkdownDocument(
            blocks: [.table(headers: ["ibex"], alignments: [.left], rows: [])],
            rawText: "ibex"
        )
        let tablePixels = try solidOrangePixelCount(for: document, query: "ibex")

        XCTAssertGreaterThan(tablePixels, 0)
    }

    func testCachedHighlightUpdatesWhenCurrentMatchIdentityChanges() throws {
        let baselinePixels = try solidOrangePixelCount(in: highlightedText("emu"))
        let seedDocument = MarkdownDocument(
            blocks: [.paragraph(text: "none"), .paragraph(text: "emu")],
            rawText: "none\n\nemu"
        )
        _ = try solidOrangePixelCount(for: seedDocument, query: "emu")

        let changedCurrentMatchDocument = MarkdownDocument(
            blocks: [.paragraph(text: "emu x"), .paragraph(text: "emu")],
            rawText: "emu x\n\nemu"
        )
        let changedCurrentMatchPixels = try solidOrangePixelCount(for: changedCurrentMatchDocument, query: "emu")

        XCTAssertLessThan(
            changedCurrentMatchPixels,
            Int(Double(baselinePixels) * 1.35),
            "Expected cached highlights to follow current match identity; baseline=\(baselinePixels), changed=\(changedCurrentMatchPixels)"
        )
    }

    func testCurrentMatchScrollTargetUsesMatchIdentity() {
        let text = "go go"
        let document = MarkdownDocument(blocks: [.paragraph(text: text)], rawText: text)
        let searchState = SearchState()
        searchState.isActive = true
        searchState.query = "go"
        searchState.search(in: document)
        searchState.nextMatch()

        XCTAssertEqual(searchState.currentMatchScrollID, "match-0-0-3-5")
    }

    private func highlightedText(_ text: String) -> some View {
        var attributed = AttributedString(text)
        attributed.backgroundColor = Color.orange
        return Text(attributed)
            .frame(width: 240, height: 80, alignment: .topLeading)
            .background(Color.white)
    }

    private func solidOrangePixelCount(for text: String, query: String = "go") throws -> Int {
        let document = MarkdownDocument(blocks: [.paragraph(text: text)], rawText: text)
        return try solidOrangePixelCount(for: document, query: query)
    }

    private func solidOrangePixelCount(for document: MarkdownDocument, query: String) throws -> Int {
        let searchState = SearchState()
        searchState.isActive = true
        searchState.query = query
        searchState.search(in: document)

        return try solidOrangePixelCount(in: MarkdownRenderer(document: document, searchState: searchState))
    }

    private func solidOrangePixelCount<V: View>(in view: V) throws -> Int {
        let hostingView = NSHostingView(
            rootView: view
                .frame(width: 240, height: 80, alignment: .topLeading)
                .background(Color.white)
        )
        hostingView.frame = CGRect(x: 0, y: 0, width: 240, height: 80)
        hostingView.layoutSubtreeIfNeeded()

        guard let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            XCTFail("Failed to create search highlight bitmap")
            return 0
        }
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)

        guard let image = bitmap.cgImage else {
            XCTFail("Failed to render search highlight image")
            return 0
        }

        return try countSolidOrangePixels(in: image)
    }

    private func countSolidOrangePixels(in image: CGImage) throws -> Int {
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            XCTFail("Failed to create pixel context")
            return 0
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        return stride(from: 0, to: pixels.count, by: 4).reduce(0) { count, offset in
            let red = pixels[offset]
            let green = pixels[offset + 1]
            let blue = pixels[offset + 2]
            let alpha = pixels[offset + 3]
            let isSolidOrange = red > 240 && green > 90 && green < 190 && blue < 80 && alpha > 240
            return count + (isSolidOrange ? 1 : 0)
        }
    }
}
