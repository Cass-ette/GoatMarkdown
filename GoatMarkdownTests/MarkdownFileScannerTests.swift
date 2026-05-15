import Foundation
import XCTest
@testable import GoatMarkdown

final class MarkdownFileScannerTests: XCTestCase {
    private var tempDir: TemporaryDirectory!

    override func tearDown() {
        tempDir = nil
        super.tearDown()
    }

    func testScanReturnsSortedRecursiveMarkdownTree() throws {
        tempDir = try TemporaryDirectory()
        try tempDir.writeFile("b.md", contents: "# B")
        try tempDir.writeFile("notes.txt", contents: "ignore")
        try tempDir.createDirectory("Docs")
        try tempDir.writeFile("Docs/a.markdown", contents: "# A")
        try tempDir.createDirectory("Empty")

        let scanner = MarkdownFileScanner(fileManager: .default)
        let tree = try scanner.scan(root: tempDir.url)

        XCTAssertEqual(tree.name, tempDir.url.lastPathComponent)
        XCTAssertEqual(tree.children.map(\.name), ["Docs", "b.md"])
        XCTAssertEqual(tree.children[0].children.map(\.name), ["a.markdown"])
    }

    func testScanOmitsFoldersWithoutMarkdownFiles() throws {
        tempDir = try TemporaryDirectory()
        try tempDir.createDirectory("Images")
        try tempDir.writeFile("Images/photo.png", contents: "binary")

        let scanner = MarkdownFileScanner(fileManager: .default)
        let tree = try scanner.scan(root: tempDir.url)

        XCTAssertTrue(tree.children.isEmpty)
    }
}

private final class TemporaryDirectory {
    let url: URL

    init() throws {
        url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    func createDirectory(_ relativePath: String) throws {
        try FileManager.default.createDirectory(
            at: url.appendingPathComponent(relativePath, isDirectory: true),
            withIntermediateDirectories: true
        )
    }

    func writeFile(_ relativePath: String, contents: String) throws {
        let fileURL = url.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
