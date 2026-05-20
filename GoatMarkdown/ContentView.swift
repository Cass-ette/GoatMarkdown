import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var state: MarkdownReaderState
    @State private var search = SearchState()
    @FocusState private var searchFieldFocused: Bool

    var body: some View {
        NavigationSplitView {
            FileBrowserSidebar(state: state, onSelect: { state.selectFile($0) })
            .frame(minWidth: 200)
        } detail: {
            if let document = state.currentDocument {
                MarkdownRenderer(
                    document: document,
                    theme: MarkdownTheme(bodyFontScale: state.bodyFontScale),
                    searchState: search,
                    pendingScrollBlockIndex: $state.pendingScrollBlockIndex,
                    onToggleBookmark: { state.toggleBookmark(for: $0) },
                    onToggleDefaultBookmark: { state.toggleDefaultBookmark(for: $0) },
                    hasBookmark: { state.hasBookmark(for: $0) },
                    isDefaultBookmark: { state.isDefaultBookmark(for: $0) }
                )
                    .overlay(alignment: .top) {
                        if search.isActive {
                            searchBar(in: document)
                        }
                    }
                    .onChange(of: search.isActive) { _, isShowing in
                        searchFieldFocused = isShowing
                    }
                    .onChange(of: state.selectedFileURL) { _, _ in
                        if let doc = state.currentDocument { search.search(in: doc) }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .toggleSearch)) { _ in
                        search.toggle()
                        if let doc = state.currentDocument { search.search(in: doc) }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .openFileCommand)) { _ in
                        openFilePanel()
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
                    state.decreaseBodyFontScale()
                } label: {
                    Image(systemName: "textformat.size.smaller")
                }
                .help("Decrease text size")
                .keyboardShortcut("-", modifiers: .command)

                Button {
                    state.increaseBodyFontScale()
                } label: {
                    Image(systemName: "textformat.size.larger")
                }
                .help("Increase text size")
                .keyboardShortcut("=", modifiers: .command)

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

    @ViewBuilder
    private func searchBar(in document: MarkdownDocument) -> some View {
        HStack(spacing: 6) {
            TextField("Find", text: $search.query)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .default))
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
                .frame(minWidth: 120)

            if search.matchCount > 0 {
                Text("\(search.currentMatchIndex + 1) of \(search.matchCount)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Button { search.previousMatch() } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(.plain)

                Button { search.nextMatch() } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(.plain)
            } else if !search.query.isEmpty {
                Text("No results")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Divider().frame(height: 14)

            Button {
                search.toggle()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
        .frame(maxWidth: 360, alignment: .trailing)
        .padding(.top, 6)
        .padding(.trailing, 12)
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
