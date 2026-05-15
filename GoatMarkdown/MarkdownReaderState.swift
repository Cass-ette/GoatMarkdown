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
        guard url != selectedFileURL else { return }
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
}
