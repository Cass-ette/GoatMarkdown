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
    @State private var editingHighlight: Highlight?
    private let noteEditorController = NoteEditorWindowController()

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
            FileBrowserSidebar(
                state: state,
                onSelect: { state.selectFile($0) },
                onEditHighlightNote: { highlight in
                    noteEditorController.show(
                        highlightID: highlight.id,
                        initialNote: highlight.note
                    ) { id, note in
                        state.updateHighlightNote(id: id, note: note)
                    }
                }
            )
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
                    isDefaultBookmark: { state.isDefaultBookmark(for: $0) },
                    onEditHighlightNote: { highlight in
                        noteEditorController.show(
                            highlightID: highlight.id,
                            initialNote: highlight.note
                        ) { id, note in
                            state.updateHighlightNote(id: id, note: note)
                        }
                    },
                    onRemoveHighlight: { id in
                        state.highlightState.remove(id: id)
                        state.saveHighlights()
                    }
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
                    .sheet(isPresented: .constant(false)) {
                        EmptyView()
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
                    applyHighlightFromSelection(in: state)
                } label: {
                    Image(systemName: "highlighter")
                }
                .help("Highlight selection")
                .keyboardShortcut("h", modifiers: [.command, .shift])

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
        .focusedValue(\.windowCommandActions, WindowCommandActions(
            toggleSearch: { toggleSearch(in: state) },
            openFile: { openFilePanel(in: state) },
            openFolder: { openFolderPanel(in: state) },
            openInNewWindow: { openInNewWindowPanel() },
            toggleHighlight: { applyHighlightFromSelection(in: state) }
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
        // NSTextView.selectedRange is in LOCAL coordinates of the focused text view.
        // SwiftUI renders one Text view per block segment (paragraph / list item / etc.),
        // each backed by its own NSTextView. So:
        //   1. Get the focused NSTextView's string (which IS the rendered plain text of one segment)
        //   2. Find which (blockIndex, textIndex) it corresponds to by matching the string
        //   3. Use selectedRange directly as the local range within that segment
        guard let textView = NSApp.keyWindow?.firstResponder as? NSTextView else {
            NSLog("[highlight] no NSTextView first responder")
            return
        }
        guard let firstRange = textView.selectedRanges.first?.rangeValue,
              firstRange.location != NSNotFound,
              firstRange.length > 0 else {
            NSLog("[highlight] empty selection, range=\(textView.selectedRanges)")
            return
        }
        guard let document = state.currentDocument else {
            NSLog("[highlight] no current document")
            return
        }

        let textViewString = textView.string as NSString
        NSLog("[highlight] textView.string length=\(textViewString.length), prefix=\(textViewString.substring(to: min(40, textViewString.length)))")
        NSLog("[highlight] selectedRange location=\(firstRange.location) length=\(firstRange.length)")

        // Find which segment this NSTextView belongs to by matching its string content
        for (blockIndex, block) in document.blocks.enumerated() {
            let segmentTexts = extractSearchableTexts(from: block)
            for (textIndex, rawText) in segmentTexts.enumerated() {
                let renderedText = renderedPlainText(rawText)
                if (renderedText as NSString) == textViewString {
                    // Match! The NSTextView is rendering this segment.
                    // Its selectedRange is in local coordinates — use directly.
                    let segmentLength = textViewString.length
                    let localStart = max(0, min(firstRange.location, segmentLength))
                    let localEnd = max(localStart, min(firstRange.location + firstRange.length, segmentLength))
                    NSLog("[highlight] matched block=\(blockIndex) textIndex=\(textIndex) range=\(localStart)..<\(localEnd)")
                    if localStart < localEnd {
                        // Find if a highlight already exists in this range
                        let range = localStart..<localEnd
                        if let existing = state.highlightState.find(blockIndex: blockIndex, textIndex: textIndex, range: range) {
                            // Already highlighted → just open note editor
                            noteEditorController.show(
                                highlightID: existing.id,
                                initialNote: existing.note
                            ) { id, note in
                                state.updateHighlightNote(id: id, note: note)
                            }
                        } else {
                            // New highlight → create it AND open note editor
                            let newHighlight = state.toggleHighlight(blockIndex: blockIndex, textIndex: textIndex, range: range)
                            if let newHighlight {
                                noteEditorController.show(
                                    highlightID: newHighlight.id,
                                    initialNote: nil
                                ) { id, note in
                                    state.updateHighlightNote(id: id, note: note)
                                }
                            }
                        }
                    }
                    return
                }
            }
        }
        NSLog("[highlight] no segment matched textView.string")
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
