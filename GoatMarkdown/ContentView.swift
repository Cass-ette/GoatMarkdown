import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    let bookmarkStore: BookmarkStore
    let shouldRestoreLastSession: Bool
    let openRequest: OpenRequest?

    @Environment(\.openWindow) private var openWindow
    @State private var state: MarkdownReaderState?
    @State private var search = SearchState()
    @State private var searchScrollTrigger = 0
    @FocusState private var searchFieldFocused: Bool

    init(
        bookmarkStore: BookmarkStore,
        shouldRestoreLastSession: Bool = false,
        openRequest: OpenRequest? = nil
    ) {
        self.bookmarkStore = bookmarkStore
        self.shouldRestoreLastSession = shouldRestoreLastSession
        self.openRequest = openRequest
    }

    var body: some View {
        Group {
            if let state {
                content(for: state)
            } else {
                ProgressView()
                    .task {
                        let created = MarkdownReaderState(bookmarkStore: bookmarkStore)
                        state = created
                        if let openRequest {
                            created.handleFileURL(URL(fileURLWithPath: openRequest.path))
                        } else if shouldRestoreLastSession {
                            created.restoreLastSession()
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private func content(for state: MarkdownReaderState) -> some View {
        @Bindable var state = state
        NavigationSplitView {
            FileBrowserSidebar(state: state, onSelect: { state.selectFile($0) })
            .frame(minWidth: 200)
        } detail: {
            if let document = state.currentDocument {
                MarkdownRenderer(
                    document: document,
                    theme: MarkdownTheme(bodyFontScale: state.bodyFontScale),
                    searchState: search,
                    highlightState: state.highlightState,
                    searchScrollTrigger: searchScrollTrigger,
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
                    toggleSearch(in: state)
                } label: {
                    Label("Find", systemImage: search.isActive ? "magnifyingglass.circle.fill" : "magnifyingglass")
                }
                .keyboardShortcut("f", modifiers: .command)
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
                    openFilePanel(in: state)
                } label: {
                    Label("Open File", systemImage: "doc.text")
                }
                Button {
                    openFolderPanel(in: state)
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
        .onKeyPress("h", phases: .down) { press in
            guard press.modifiers == [.command, .shift] else { return .ignored }
            guard state.currentDocument != nil else { return .ignored }
            // Only handle when markdown text is the first responder (not search field, sidebar, etc.)
            guard NSApp.keyWindow?.firstResponder is NSTextView else { return .ignored }
            applyHighlightFromSelection(in: state)
            return .handled
        }
        .focusedValue(\.windowCommandActions, WindowCommandActions(
            toggleSearch: { toggleSearch(in: state) },
            openFile: { openFilePanel(in: state) },
            openFolder: { openFolderPanel(in: state) },
            openInNewWindow: { openInNewWindowPanel() }
        ))
    }

    @ViewBuilder
    private func searchBar(in document: MarkdownDocument) -> some View {
        HStack(spacing: 6) {
            TextField("Find", text: $search.query)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .default))
                .focused($searchFieldFocused)
                .onSubmit {
                    goToNextSearchMatch(in: document)
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

                Button { goToPreviousSearchMatch() } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(.plain)

                Button { goToNextSearchMatch(in: document) } label: {
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

    private func toggleSearch(in state: MarkdownReaderState) {
        search.toggle()
        if let doc = state.currentDocument { search.search(in: doc) }
    }

    private func goToNextSearchMatch(in document: MarkdownDocument) {
        if search.matchCount > 0 {
            search.nextMatch()
        } else {
            search.search(in: document)
        }
        searchScrollTrigger += 1
    }

    private func goToPreviousSearchMatch() {
        search.previousMatch()
        searchScrollTrigger += 1
    }

    private func openFolderPanel(in state: MarkdownReaderState) {
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

    private func openFilePanel(in state: MarkdownReaderState) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.init(filenameExtension: "md")!, .init(filenameExtension: "markdown")!]
        panel.prompt = "Open"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            state.openFile(url)
        }
    }

    private func openInNewWindowPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Open in New Window"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            openWindow(value: OpenRequest(path: url.path))
        }
    }

    private func applyHighlightFromSelection(in state: MarkdownReaderState) {
        // MVP: read NSTextView selection and map to (blockIndex, textIndex, range) using RENDERED
        // plain text. Critical: offsets must be in post-markdown text (what user sees in NSTextView
        // and what applyHighlights() expects), not raw block text (which has **, *, [, etc.).
        // This mirrors SearchState's extractSearchableTexts + renderedPlainText convention.
        guard let textView = NSApp.keyWindow?.firstResponder as? NSTextView else { return }
        guard let firstRange = textView.selectedRanges.first?.rangeValue,
              firstRange.location != NSNotFound,
              firstRange.length > 0 else { return }

        guard let document = state.currentDocument else { return }

        var characterOffset = 0
        for (blockIndex, block) in document.blocks.enumerated() {
            let segmentTexts = extractSearchableTexts(from: block)
            for (textIndex, rawText) in segmentTexts.enumerated() {
                let renderedText = renderedPlainText(rawText)
                let segmentLength = (renderedText as NSString).length
                let segmentStart = characterOffset
                let segmentEnd = characterOffset + segmentLength

                if firstRange.location < segmentEnd && firstRange.location + firstRange.length > segmentStart {
                    let localStart = max(0, firstRange.location - segmentStart)
                    let localEnd = min(segmentLength, firstRange.location + firstRange.length - segmentStart)
                    if localStart < localEnd {
                        state.toggleHighlight(blockIndex: blockIndex, textIndex: textIndex, range: localStart..<localEnd)
                    }
                    return
                }
                characterOffset = segmentEnd
            }
        }
    }

    // Mirrors SearchState's extraction + rendering. Duplicated intentionally to keep ContentView
    // independent of SearchState internals; if a third caller appears, extract to a shared utility.
    private func extractSearchableTexts(from block: MarkdownBlock) -> [String] {
        switch block {
        case .heading(_, let text): return [text]
        case .paragraph(let text): return [text]
        case .blockquote(let text): return [text]
        case .unorderedList(let items): return items
        case .orderedList(let items): return items
        case .codeBlock(_, let code): return [code]
        case .table(let headers, _, let rows): return headers + rows.flatMap { $0 }
        case .link(let text, _): return [text]
        case .image(let alt, _): return [alt]
        case .thematicBreak: return []
        }
    }

    private func renderedPlainText(_ text: String) -> String {
        let attributed = (try? AttributedString(markdown: text)) ?? AttributedString(text)
        return String(attributed.characters)
    }
}
