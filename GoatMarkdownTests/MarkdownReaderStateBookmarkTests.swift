import Foundation
import XCTest
@testable import GoatMarkdown

@MainActor
final class MarkdownReaderStateBookmarkTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var tempFile: URL!
    private var otherTempFile: URL!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "ReaderStateBookmarkTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        tempFile = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("\(UUID().uuidString).md")
        try "# Title\n\nFirst paragraph\n\nSecond paragraph"
            .write(to: tempFile, atomically: true, encoding: .utf8)
        otherTempFile = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("\(UUID().uuidString)-other.md")
        try "# Other\n\nDifferent paragraph"
            .write(to: otherTempFile, atomically: true, encoding: .utf8)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: tempFile)
        try? FileManager.default.removeItem(at: otherTempFile)
        defaults = nil
        suiteName = nil
        tempFile = nil
        otherTempFile = nil
        try await super.tearDown()
    }

    func testToggleBookmarkAddsThenRemovesForSameBlock() {
        let state = makeState()
        state.selectFile(tempFile)

        state.toggleBookmark(for: 1)
        XCTAssertEqual(state.bookmarkStore.bookmarks(for: tempFile.path).count, 1)

        state.toggleBookmark(for: 1)
        XCTAssertEqual(state.bookmarkStore.bookmarks(for: tempFile.path).count, 0)
    }

    func testToggleDefaultBookmarkSetsAndUnsetsDefaultFlag() {
        let state = makeState()
        state.selectFile(tempFile)

        state.toggleDefaultBookmark(for: 1)
        XCTAssertTrue(state.bookmarkStore.bookmarks(for: tempFile.path).contains { $0.isDefault })

        state.toggleDefaultBookmark(for: 1)
        XCTAssertFalse(state.bookmarkStore.bookmarks(for: tempFile.path).contains { $0.isDefault })
    }

    func testBookmarksAreSharedAcrossIndependentReaderStates() {
        let store = BookmarkStore(defaults: defaults)
        let first = makeState(store: store)
        let second = makeState(store: store)

        first.openFile(tempFile)
        second.openFile(tempFile)

        first.toggleBookmark(for: 1)

        XCTAssertEqual(second.bookmarkStore.bookmarks(for: tempFile.path).count, 1)
        XCTAssertTrue(second.hasBookmark(for: 1))
    }

    func testIndependentStatesKeepSeparateSelectedFiles() {
        let store = BookmarkStore(defaults: defaults)
        let first = makeState(store: store)
        let second = makeState(store: store)

        first.openFile(tempFile)
        second.openFile(otherTempFile)

        XCTAssertEqual(first.selectedFileURL, tempFile)
        XCTAssertEqual(second.selectedFileURL, otherTempFile)
        XCTAssertEqual(first.openMode, .singleFile(tempFile))
        XCTAssertEqual(second.openMode, .singleFile(otherTempFile))
    }

    func testOpenFileUsesSingleFileModeWithoutFileTree() {
        let state = makeState()

        state.openFile(tempFile)

        XCTAssertNil(state.fileTree)
        XCTAssertEqual(state.selectedFileURL, tempFile)
        XCTAssertNotNil(state.currentDocument)
        XCTAssertEqual(state.openMode, .singleFile(tempFile))
    }

    func testRestoreLastSessionPreservesSingleFileMode() {
        let state = makeState()
        state.openFile(tempFile)

        let restored = makeState()
        restored.restoreLastSession()

        XCTAssertEqual(restored.openMode, .singleFile(tempFile))
        XCTAssertNil(restored.fileTree)
        XCTAssertEqual(restored.selectedFileURL, tempFile)
    }

    func testRestoreLastSessionPreservesDirectoryModeAndSelectedFile() throws {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("\(UUID().uuidString)-folder", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let file = folder.appendingPathComponent("selected.md")
        try "# Selected".write(to: file, atomically: true, encoding: .utf8)

        let state = makeState()
        state.openFolder(folder)
        state.selectFile(file)

        let restored = makeState()
        restored.restoreLastSession()

        XCTAssertEqual(restored.openMode, .directory(rootURL: folder))
        XCTAssertNotNil(restored.fileTree)
        XCTAssertEqual(restored.selectedFileURL, file)
    }

    private func makeState(store: BookmarkStore? = nil) -> MarkdownReaderState {
        MarkdownReaderState(defaults: defaults, bookmarkStore: store ?? BookmarkStore(defaults: defaults))
    }
}
