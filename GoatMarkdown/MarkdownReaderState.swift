import SwiftUI

@Observable
final class MarkdownReaderState {
    var fileTree: FileNode?
    var selectedFileURL: URL?
    var currentDocument: MarkdownDocument?
    var isLoading = false
    var showSearch = false
    var searchText = ""

    private let scanner = MarkdownFileScanner(fileManager: .default)
    private let defaults = UserDefaults.standard
    private static let lastFolderKey = "lastOpenedFolderPath"
    private static let lastFileKey = "lastSelectedFilePath"

    func openFolder(_ url: URL) {
        do {
            fileTree = try scanner.scan(root: url)
            selectedFileURL = nil
            currentDocument = nil
            defaults.set(url.path, forKey: Self.lastFolderKey)
            defaults.removeObject(forKey: Self.lastFileKey)
        } catch {
            fileTree = nil
        }
    }

    func selectFile(_ url: URL) {
        selectedFileURL = url
        isLoading = true
        defer { isLoading = false }

        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            currentDocument = MarkdownParser.parse(text)
            defaults.set(url.path, forKey: Self.lastFileKey)
        } catch {
            currentDocument = MarkdownDocument(blocks: [.paragraph(text: "Unable to read file: \(error.localizedDescription)")], rawText: "")
        }
    }

    func handleFileURL(_ url: URL) {
        let path = url.path
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        if isDir.boolValue {
            openFolder(url)
        } else {
            openFolder(url.deletingLastPathComponent())
            selectFile(url)
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
            let parentDir = fileURL.deletingLastPathComponent()
            openFolder(parentDir)
            selectFile(fileURL)
        }
    }

    func toggleSearch() {
        showSearch.toggle()
        if !showSearch { searchText = "" }
    }

    func restoreLastSession() {
        let lastFilePath = defaults.string(forKey: Self.lastFileKey)
        let lastFolderPath = defaults.string(forKey: Self.lastFolderKey)

        if let lastFilePath {
            let fileURL = URL(fileURLWithPath: lastFilePath)
            guard FileManager.default.fileExists(atPath: lastFilePath) else {
                defaults.removeObject(forKey: Self.lastFileKey)
                if let lastFolderPath {
                    let folderURL = URL(fileURLWithPath: lastFolderPath)
                    if FileManager.default.fileExists(atPath: lastFolderPath) {
                        openFolder(folderURL)
                    }
                }
                return
            }
            let parentDir = fileURL.deletingLastPathComponent()
            openFolder(parentDir)
            selectFile(fileURL)
        } else if let lastFolderPath {
            let folderURL = URL(fileURLWithPath: lastFolderPath)
            guard FileManager.default.fileExists(atPath: lastFolderPath) else {
                defaults.removeObject(forKey: Self.lastFolderKey)
                return
            }
            openFolder(folderURL)
        }
    }
}
