import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var state: MarkdownReaderState
    @State private var search = SearchState()
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
                MarkdownRenderer(document: document, searchState: search)
                    .overlay(alignment: .top) {
                        if search.isActive {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)

                                TextField("Search", text: $search.query)
                                    .textFieldStyle(.plain)
                                    .font(.body)
                                    .focused($searchFieldFocused)
                                    .onSubmit {
                                        if search.matchCount > 0 {
                                            search.nextMatch()
                                        } else {
                                            search.search(in: document)
                                        }
                                    }
                                    .onChange(of: search.query) { _, _ in
                                        search.search(in: document)
                                    }

                                if search.matchCount > 0 {
                                    Text("\(search.currentMatchIndex + 1)/\(search.matchCount)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()

                                    Button {
                                        search.previousMatch()
                                    } label: {
                                        Image(systemName: "chevron.up")
                                    }
                                    .buttonStyle(.plain)

                                    Button {
                                        search.nextMatch()
                                    } label: {
                                        Image(systemName: "chevron.down")
                                    }
                                    .buttonStyle(.plain)
                                } else if !search.query.isEmpty {
                                    Text("0/0")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }

                                Button {
                                    search.toggle()
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
                    .onChange(of: search.isActive) { _, isShowing in
                        searchFieldFocused = isShowing
                    }
                    .onChange(of: state.selectedFileURL) { _, _ in
                        if let doc = state.currentDocument { search.search(in: doc) }
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
                    search.toggle()
                    if let doc = state.currentDocument { search.search(in: doc) }
                } label: {
                    Label("Find", systemImage: search.isActive ? "magnifyingglass.circle.fill" : "magnifyingglass")
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
            search.isActive = true
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
