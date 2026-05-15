import SwiftUI

@Observable
final class MarkdownReaderState {
    var fileTree: FileNode?
    var selectedFileURL: URL?
    var currentDocument: MarkdownDocument?
    var isLoading = false

    private let scanner = MarkdownFileScanner(fileManager: .default)

    func openFolder(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            fileTree = try scanner.scan(root: url)
            selectedFileURL = nil
            currentDocument = nil
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
        } catch {
            currentDocument = MarkdownDocument(blocks: [.paragraph(text: "Unable to read file: \(error.localizedDescription)")], rawText: "")
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

        // Check if path is a directory or file
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
}
