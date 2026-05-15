import SwiftUI

struct ContentView: View {
    @State private var state = MarkdownReaderState()

    var body: some View {
        NavigationSplitView {
            FileBrowserSidebar(
                tree: state.fileTree,
                selectedFileURL: Binding(
                    get: { state.selectedFileURL },
                    set: { if let url = $0 { state.selectFile(url) } }
                ),
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
            ToolbarItem(placement: .primaryAction) {
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
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            state.openFolder(url)
        }
    }
}
