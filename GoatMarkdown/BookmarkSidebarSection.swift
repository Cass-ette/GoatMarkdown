import SwiftUI

struct BookmarkSidebarSection: View {
    @Bindable var state: MarkdownReaderState

    var body: some View {
        if state.currentDocument != nil, let filePath = state.selectedFileURL?.path {
            let bookmarks = state.bookmarkStore.bookmarks(for: filePath)
            Section("Bookmarks") {
                if bookmarks.isEmpty {
                    Text("No bookmarks for this file")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(bookmarks) { bookmark in
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
                            }
                        )
                    }
                }
            }
        }
    }
}

private struct BookmarkRow: View {
    let bookmark: Bookmark
    let onSelect: () -> Void
    let onToggleDefault: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onToggleDefault) {
                Image(systemName: bookmark.isDefault ? "star.fill" : "star")
                    .foregroundStyle(bookmark.isDefault ? Color.yellow : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(bookmark.isDefault ? "Unset auto-open default" : "Set as auto-open default")

            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(bookmark.title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    if !bookmark.preview.isEmpty {
                        Text(bookmark.preview)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .contextMenu {
            Button(bookmark.isDefault ? "Unset default" : "Set as default", action: onToggleDefault)
            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}
