import SwiftUI

enum OpenMode: Equatable {
    case empty
    case directory(rootURL: URL)
    case singleFile(URL)
}

struct OpenRequest: Codable, Hashable, Identifiable {
    let id: UUID
    let path: String

    init(path: String) {
        self.id = UUID()
        self.path = path
    }
}

@Observable
final class MarkdownReaderState {
    var fileTree: FileNode?
    var selectedFileURL: URL?
    var currentDocument: MarkdownDocument?
    var isLoading = false
    var pendingScrollBlockIndex: Int?
    var bodyFontScale: Double
    var openMode: OpenMode = .empty
    var highlightState = HighlightState()
    let bookmarkStore: BookmarkStore
    let highlightStore: HighlightStore

    private let scanner = MarkdownFileScanner(fileManager: .default)
    private let defaults: UserDefaults
    private static let lastOpenModeKey = "lastOpenMode"
    private static let lastFolderKey = "lastOpenedFolderPath"
    private static let lastFileKey = "lastSelectedFilePath"
    private static let bodyFontScaleKey = "bodyFontScale"
    private static let directoryModeValue = "directory"
    private static let singleFileModeValue = "singleFile"
    private static let minimumBodyFontScale = 0.8
    private static let maximumBodyFontScale = 1.8
    private static let bodyFontScaleStep = 0.1

    init(defaults: UserDefaults = .standard, bookmarkStore: BookmarkStore = BookmarkStore(), highlightStore: HighlightStore = HighlightStore()) {
        self.defaults = defaults
        self.bookmarkStore = bookmarkStore
        self.highlightStore = highlightStore
        self.bodyFontScale = defaults.object(forKey: Self.bodyFontScaleKey) as? Double ?? 1.0
    }

    func openFolder(_ url: URL) {
        do {
            fileTree = try scanner.scan(root: url)
            openMode = .directory(rootURL: url)
            selectedFileURL = nil
            currentDocument = nil
            pendingScrollBlockIndex = nil
            defaults.set(Self.directoryModeValue, forKey: Self.lastOpenModeKey)
            defaults.set(url.path, forKey: Self.lastFolderKey)
            defaults.removeObject(forKey: Self.lastFileKey)
        } catch {
            fileTree = nil
            openMode = .empty
        }
    }

    func openFile(_ url: URL) {
        fileTree = nil
        openMode = .singleFile(url)
        defaults.set(Self.singleFileModeValue, forKey: Self.lastOpenModeKey)
        defaults.removeObject(forKey: Self.lastFolderKey)
        selectFile(url)
    }

    func selectFile(_ url: URL) {
        selectedFileURL = url
        isLoading = true
        defer { isLoading = false }

        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            let document = MarkdownParser.parse(text)
            currentDocument = document
            defaults.set(url.path, forKey: Self.lastFileKey)
            pendingScrollBlockIndex = resolvedDefaultBookmarkIndex(in: document, filePath: url.path)
            let stored = highlightStore.highlights(for: url.path)
            highlightState.load(stored)
        } catch {
            currentDocument = MarkdownDocument(blocks: [.paragraph(text: "Unable to read file: \(error.localizedDescription)")], rawText: "")
            pendingScrollBlockIndex = nil
            highlightState.load([])
        }
    }

    func resolvedBlockIndex(for bookmark: Bookmark) -> Int? {
        guard let document = currentDocument else { return nil }
        return BookmarkResolver.resolveBlockIndex(
            signature: bookmark.blockSignature,
            originalIndex: bookmark.blockIndex,
            in: document
        )
    }

    func scrollToBookmark(_ bookmark: Bookmark) {
        guard let resolved = resolvedBlockIndex(for: bookmark) else { return }
        pendingScrollBlockIndex = resolved
    }

    func increaseBodyFontScale() {
        bodyFontScale = min(Self.maximumBodyFontScale, bodyFontScale + Self.bodyFontScaleStep)
        persistBodyFontScale()
    }

    func decreaseBodyFontScale() {
        bodyFontScale = max(Self.minimumBodyFontScale, bodyFontScale - Self.bodyFontScaleStep)
        persistBodyFontScale()
    }

    func addBookmarkForFirstBlock(isDefault: Bool = false) {
        guard let filePath = selectedFileURL?.path,
              let document = currentDocument,
              let firstBlock = document.blocks.first else { return }
        let bookmark = BookmarkResolver.makeBookmark(for: firstBlock, blockIndex: 0, isDefault: isDefault)
        bookmarkStore.add(bookmark, for: filePath)
    }

    func addBookmark(for blockIndex: Int, isDefault: Bool = false) {
        guard let filePath = selectedFileURL?.path,
              let document = currentDocument,
              document.blocks.indices.contains(blockIndex) else { return }
        let block = document.blocks[blockIndex]
        let bookmark = BookmarkResolver.makeBookmark(for: block, blockIndex: blockIndex, isDefault: isDefault)
        bookmarkStore.add(bookmark, for: filePath)
    }

    func setDefaultBookmark(for blockIndex: Int) {
        guard let filePath = selectedFileURL?.path,
              let document = currentDocument,
              document.blocks.indices.contains(blockIndex) else { return }
        let block = document.blocks[blockIndex]
        let signature = BookmarkResolver.signature(for: block)

        if let existing = bookmarkStore.bookmarks(for: filePath).first(where: { $0.blockSignature == signature }) {
            bookmarkStore.setDefault(existing.id, for: filePath)
            return
        }
        let bookmark = BookmarkResolver.makeBookmark(for: block, blockIndex: blockIndex, isDefault: true)
        bookmarkStore.add(bookmark, for: filePath)
    }

    func hasBookmark(for blockIndex: Int) -> Bool {
        guard let filePath = selectedFileURL?.path,
              let document = currentDocument,
              document.blocks.indices.contains(blockIndex) else { return false }
        let signature = BookmarkResolver.signature(for: document.blocks[blockIndex])
        return bookmarkStore.bookmarks(for: filePath).contains { $0.blockSignature == signature }
    }

    func isDefaultBookmark(for blockIndex: Int) -> Bool {
        guard let filePath = selectedFileURL?.path,
              let document = currentDocument,
              document.blocks.indices.contains(blockIndex) else { return false }
        let signature = BookmarkResolver.signature(for: document.blocks[blockIndex])
        return bookmarkStore.bookmarks(for: filePath).contains { $0.blockSignature == signature && $0.isDefault }
    }

    func toggleBookmark(for blockIndex: Int) {
        guard let filePath = selectedFileURL?.path,
              let document = currentDocument,
              document.blocks.indices.contains(blockIndex) else { return }
        let block = document.blocks[blockIndex]
        let signature = BookmarkResolver.signature(for: block)
        if let existing = bookmarkStore.bookmarks(for: filePath).first(where: { $0.blockSignature == signature }) {
            bookmarkStore.remove(existing.id, for: filePath)
        } else {
            let bookmark = BookmarkResolver.makeBookmark(for: block, blockIndex: blockIndex, isDefault: false)
            bookmarkStore.add(bookmark, for: filePath)
        }
    }

    func toggleDefaultBookmark(for blockIndex: Int) {
        guard let filePath = selectedFileURL?.path,
              let document = currentDocument,
              document.blocks.indices.contains(blockIndex) else { return }
        let block = document.blocks[blockIndex]
        let signature = BookmarkResolver.signature(for: block)
        if let existing = bookmarkStore.bookmarks(for: filePath).first(where: { $0.blockSignature == signature }) {
            if existing.isDefault {
                bookmarkStore.setDefault(UUID(), for: filePath)
            } else {
                bookmarkStore.setDefault(existing.id, for: filePath)
            }
        } else {
            let bookmark = BookmarkResolver.makeBookmark(for: block, blockIndex: blockIndex, isDefault: true)
            bookmarkStore.add(bookmark, for: filePath)
        }
    }

    func saveHighlights() {
        guard let filePath = selectedFileURL?.path else { return }
        highlightStore.setHighlights(highlightState.highlights, for: filePath)
    }

    @discardableResult
    func toggleHighlight(blockIndex: Int, textIndex: Int, range: Range<Int>) -> Highlight? {
        let result = highlightState.toggle(blockIndex: blockIndex, textIndex: textIndex, range: range)
        saveHighlights()
        return result
    }

    func updateHighlightNote(id: UUID, note: String?) {
        highlightState.updateNote(id: id, note: note)
        saveHighlights()
    }

    private func persistBodyFontScale() {
        defaults.set(bodyFontScale, forKey: Self.bodyFontScaleKey)
    }

    private func resolvedDefaultBookmarkIndex(in document: MarkdownDocument, filePath: String) -> Int? {
        guard let bookmark = bookmarkStore.defaultBookmark(for: filePath) else { return nil }
        return BookmarkResolver.resolveBlockIndex(
            signature: bookmark.blockSignature,
            originalIndex: bookmark.blockIndex,
            in: document
        )
    }

    func handleFileURL(_ url: URL) {
        let path = url.path
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        if isDir.boolValue {
            openFolder(url)
        } else {
            openFile(url)
        }
    }

    func handleExternalURL(_ url: URL) {
        guard url.scheme == "goatmarkdown" else { return }
        guard url.host == "open" else { return }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let queryItems = components?.queryItems else { return }

        let path = queryItems.first(where: { $0.name == "path" })?.value
        guard let path, !path.isEmpty else { return }

        let fileURL = URL(fileURLWithPath: path)

        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDir)

        if isDir.boolValue {
            openFolder(fileURL)
        } else {
            openFile(fileURL)
        }
    }

    func restoreLastSession() {
        let lastMode = defaults.string(forKey: Self.lastOpenModeKey)
        let lastFilePath = defaults.string(forKey: Self.lastFileKey)
        let lastFolderPath = defaults.string(forKey: Self.lastFolderKey)

        if lastMode == Self.singleFileModeValue, let lastFilePath {
            let fileURL = URL(fileURLWithPath: lastFilePath)
            guard FileManager.default.fileExists(atPath: lastFilePath) else {
                defaults.removeObject(forKey: Self.lastFileKey)
                return
            }
            openFile(fileURL)
            return
        }

        if lastMode == Self.directoryModeValue, let lastFolderPath {
            restoreDirectory(folderPath: lastFolderPath, selectedFilePath: lastFilePath)
            return
        }

        if let lastFolderPath {
            restoreDirectory(folderPath: lastFolderPath, selectedFilePath: lastFilePath)
        } else if let lastFilePath {
            let fileURL = URL(fileURLWithPath: lastFilePath)
            guard FileManager.default.fileExists(atPath: lastFilePath) else {
                defaults.removeObject(forKey: Self.lastFileKey)
                return
            }
            openFile(fileURL)
        }
    }

    private func restoreDirectory(folderPath: String, selectedFilePath: String?) {
        let folderURL = URL(fileURLWithPath: folderPath)
        guard FileManager.default.fileExists(atPath: folderPath) else {
            defaults.removeObject(forKey: Self.lastFolderKey)
            return
        }
        openFolder(folderURL)

        guard let selectedFilePath,
              FileManager.default.fileExists(atPath: selectedFilePath) else { return }
        selectFile(URL(fileURLWithPath: selectedFilePath))
    }
}
