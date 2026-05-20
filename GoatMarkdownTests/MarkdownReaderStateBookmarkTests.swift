import Foundation
import XCTest
@testable import GoatMarkdown

@MainActor
final class MarkdownReaderStateBookmarkTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var tempFile: URL!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "ReaderStateBookmarkTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        tempFile = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("\(UUID().uuidString).md")
        try "# Title\n\nFirst paragraph\n\nSecond paragraph"
            .write(to: tempFile, atomically: true, encoding: .utf8)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: tempFile)
        defaults = nil
        suiteName = nil
        tempFile = nil
        try await super.tearDown()
    }

    func testToggleBookmarkAddsThenRemovesForSameBlock() {
        let state = MarkdownReaderState(defaults: defaults)
        state.selectFile(tempFile)

        state.toggleBookmark(for: 1)
        XCTAssertEqual(state.bookmarkStore.bookmarks(for: tempFile.path).count, 1)

        state.toggleBookmark(for: 1)
        XCTAssertEqual(state.bookmarkStore.bookmarks(for: tempFile.path).count, 0)
    }

    func testToggleDefaultBookmarkSetsAndUnsetsDefaultFlag() {
        let state = MarkdownReaderState(defaults: defaults)
        state.selectFile(tempFile)

        state.toggleDefaultBookmark(for: 1)
        XCTAssertTrue(state.bookmarkStore.bookmarks(for: tempFile.path).contains { $0.isDefault })

        state.toggleDefaultBookmark(for: 1)
        XCTAssertFalse(state.bookmarkStore.bookmarks(for: tempFile.path).contains { $0.isDefault })
    }
}
