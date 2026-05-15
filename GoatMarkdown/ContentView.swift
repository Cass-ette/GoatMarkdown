import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var state: MarkdownReaderState
    @State private var searchText = ""
    @State private var showSearch = false

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
                MarkdownRenderer(document: document, searchText: showSearch ? searchText : "")
                    .overlay(alignment: .top) {
                        if showSearch {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                TextField("Search", text: $searchText)
                                    .textFieldStyle(.plain)
                                    .font(.body)
                                if !searchText.isEmpty {
                                    Button {
                                        searchText = ""
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                Button {
                                    showSearch = false
                                    searchText = ""
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
                    showSearch.toggle()
                    if !showSearch { searchText = "" }
                } label: {
                    Label("Find", systemImage: showSearch ? "magnifyingglass.circle.fill" : "magnifyingglass")
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
            showSearch = true
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
