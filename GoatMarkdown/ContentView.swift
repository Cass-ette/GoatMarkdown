import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var state = MarkdownReaderState()

    var body: some View {
        NavigationSplitView {
            FileBrowserSidebar(
                tree: state.fileTree,
                selectedFileURL: $state.selectedFileURL,
                onSelect: { state.selectFile($0) }
            )
            .frame(minWidth: 200)
        } detail: {
            if let document = state.currentDocument {
                MarkdownRenderer(document: document)
            } else if state.isLoading {
                ProgressView()
            } else {
                Text("Select a Markdown file to read")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    openFilePanel()
                } label: {
                    Label("Open File", systemImage: "doc.text")
                }
                Button {
                    openFolderPanel()
                } label: {
                    Label("Open Folder", systemImage: "folder")
                }
            }
        }
    }

    private func openFolderPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            state.openFolder(url)
        }
    }

    private func openFilePanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.init(filenameExtension: "md")!, .init(filenameExtension: "markdown")!]
        panel.prompt = "Open"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let parentDir = url.deletingLastPathComponent()
            state.openFolder(parentDir)
            state.selectFile(url)
        }
    }
}
