import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var state: MarkdownReaderState
    @FocusState private var searchFieldFocused: Bool

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
                MarkdownRenderer(document: document, searchText: state.showSearch ? state.searchText : "")
                    .overlay(alignment: .top) {
                        if state.showSearch {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                TextField("Search", text: $state.searchText)
                                    .textFieldStyle(.plain)
                                    .font(.body)
                                    .focused($searchFieldFocused)
                                if !state.searchText.isEmpty {
                                    Button {
                                        state.searchText = ""
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                Button {
                                    state.showSearch = false
                                    state.searchText = ""
                                } label: {
                                    Image(systemName: "xmark")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                            .padding()
                        }
                    }
                    .onChange(of: state.showSearch) { _, isShowing in
                        searchFieldFocused = isShowing
                    }
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
                    state.toggleSearch()
                } label: {
                    Label("Find", systemImage: state.showSearch ? "magnifyingglass.circle.fill" : "magnifyingglass")
                }
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
        .onKeyPress(.init("/")) {
            guard state.currentDocument != nil else { return .ignored }
            state.showSearch = true
            return .handled
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
