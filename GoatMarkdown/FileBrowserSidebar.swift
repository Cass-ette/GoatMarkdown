import SwiftUI

struct FileBrowserSidebar: View {
    @Bindable var state: MarkdownReaderState
    let onSelect: (URL) -> Void

    var body: some View {
        switch state.openMode {
        case .singleFile:
            bookmarkList
        case .directory, .empty:
            directorySidebar
        }
    }

    @ViewBuilder
    private var directorySidebar: some View {
        Group {
            if let tree = state.fileTree {
                if tree.children.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("No Markdown files found")
                            .foregroundStyle(.secondary)
                            .padding()
                        bookmarkList
                    }
                } else {
                    List(selection: $state.selectedFileURL) {
                        Section("Files") {
                            ForEach(tree.children) { child in
                                FileNodeRow(node: child)
                            }
                        }
                        BookmarkSidebarSection(state: state)
                        HighlightSidebarSection(
                            state: state,
                            onEditNote: { _ in },
                            onRemove: { id in
                                state.highlightState.remove(id: id)
                                state.saveHighlights()
                            }
                        )
                    }
                    .listStyle(.sidebar)
                    .onChange(of: state.selectedFileURL) { _, newURL in
                        if let newURL {
                            onSelect(newURL)
                        }
                    }
                }
            } else {
                Text("Open a folder to start reading")
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
    }

    @ViewBuilder
    private var bookmarkList: some View {
        List {
            BookmarkSidebarSection(state: state)
            HighlightSidebarSection(
                state: state,
                onEditNote: { _ in },
                onRemove: { id in
                    state.highlightState.remove(id: id)
                    state.saveHighlights()
                }
            )
        }
        .listStyle(.sidebar)
    }
}

struct FileNodeRow: View {
    let node: FileNode

    var body: some View {
        if node.isDirectory {
            DisclosureGroup {
                ForEach(node.children) { child in
                    FileNodeRow(node: child)
                }
            } label: {
                Label(node.name, systemImage: "folder")
            }
        } else {
            Label(node.name, systemImage: "doc.text")
                .tag(node.url)
        }
    }
}
