import SwiftUI

struct BookmarkSidebarSection: View {
    @Bindable var state: MarkdownReaderState
    @State private var selectedTag: String?
    @State private var editingBookmarkForTags: Bookmark?
    @State private var showTagEditor = false

    var body: some View {
        if state.currentDocument != nil, let filePath = state.selectedFileURL?.path {
            let allBookmarks = state.bookmarkStore.bookmarks(for: filePath)
            let allTags = state.bookmarkStore.allTags(for: filePath)
            let filteredBookmarks = filteredBookmarks(allBookmarks)

            Section("Bookmarks") {
                if !allTags.isEmpty {
                    Picker("Filter", selection: $selectedTag) {
                        Text("All Bookmarks").tag(nil as String?)
                        ForEach(allTags, id: \.self) { tag in
                            Label(tag, systemImage: "tag")
                                .tag(tag as String?)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                if filteredBookmarks.isEmpty {
                    Text(selectedTag != nil ? "No bookmarks with this tag" : "No bookmarks for this file")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredBookmarks) { bookmark in
                        BookmarkRow(
                            bookmark: bookmark,
                            onSelect: { state.scrollToBookmark(bookmark) },
                            onToggleDefault: {
                                if bookmark.isDefault {
                                    state.bookmarkStore.setDefault(UUID(), for: filePath)
                                } else {
                                    state.bookmarkStore.setDefault(bookmark.id, for: filePath)
                                }
                            },
                            onDelete: {
                                state.bookmarkStore.remove(bookmark.id, for: filePath)
                            },
                            onEditTags: {
                                editingBookmarkForTags = bookmark
                                showTagEditor = true
                            }
                        )
                    }
                }
            }
            .sheet(isPresented: $showTagEditor) {
                if let bookmark = editingBookmarkForTags {
                    TagEditorSheet(
                        bookmarkID: bookmark.id,
                        isPresented: $showTagEditor,
                        initialTags: bookmark.tags,
                        existingTags: allTags,
                        onSave: { id, tags in
                            state.bookmarkStore.updateTags(id, tags: tags, for: filePath)
                        }
                    )
                }
            }
        }
    }

    private func filteredBookmarks(_ bookmarks: [Bookmark]) -> [Bookmark] {
        guard let tag = selectedTag else { return bookmarks }
        return bookmarks.filter { $0.tags.contains(tag) }
    }
}

private struct BookmarkRow: View {
    let bookmark: Bookmark
    let onSelect: () -> Void
    let onToggleDefault: () -> Void
    let onDelete: () -> Void
    let onEditTags: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onToggleDefault) {
                Image(systemName: bookmark.isDefault ? "star.fill" : "star")
                    .foregroundStyle(bookmark.isDefault ? Color.yellow : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(bookmark.isDefault ? "Unset auto-open default" : "Set as auto-open default")

            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(bookmark.title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    if !bookmark.preview.isEmpty {
                        Text(bookmark.preview)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if !bookmark.tags.isEmpty {
                        HStack(spacing: 3) {
                            ForEach(bookmark.tags, id: \.self) { tag in
                                TagPillView(tag: tag)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .contextMenu {
            Button(bookmark.isDefault ? "Unset default" : "Set as default", action: onToggleDefault)
            Button("Edit Tags", action: onEditTags)
            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}
