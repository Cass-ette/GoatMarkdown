import SwiftUI

struct HighlightSidebarSection: View {
    @Bindable var state: MarkdownReaderState
    var onEditNote: (Highlight) -> Void
    var onRemove: (UUID) -> Void

    var body: some View {
        if state.currentDocument != nil, let filePath = state.selectedFileURL?.path {
            let highlights = state.highlightState.highlights
            Section("Highlights") {
                if highlights.isEmpty {
                    Text("No highlights in this file")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(highlights) { highlight in
                        HighlightRow(
                            highlight: highlight,
                            snippet: snippetText(for: highlight),
                            onEditNote: { onEditNote(highlight) },
                            onRemove: { onRemove(highlight.id) }
                        )
                    }
                }
            }
        }
    }

    private func snippetText(for highlight: Highlight) -> String {
        guard let document = state.currentDocument,
              document.blocks.indices.contains(highlight.blockIndex) else {
            return "(block unavailable)"
        }
        let block = document.blocks[highlight.blockIndex]
        let segments = extractSegments(from: block)
        guard highlight.textIndex < segments.count else { return "(segment unavailable)" }
        let fullText = segments[highlight.textIndex]
        let startIdx = fullText.index(fullText.startIndex, offsetBy: min(highlight.rangeStart, fullText.count))
        let endIdx = fullText.index(fullText.startIndex, offsetBy: min(highlight.rangeEnd, fullText.count))
        return String(fullText[startIdx..<endIdx])
    }

    private func extractSegments(from block: MarkdownBlock) -> [String] {
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
}

private struct HighlightRow: View {
    let highlight: Highlight
    let snippet: String
    let onEditNote: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Rectangle()
                .fill(highlight.color.swiftUIColor)
                .frame(width: 3)
                .clipShape(RoundedRectangle(cornerRadius: 1.5))

            VStack(alignment: .leading, spacing: 2) {
                Text(snippet.isEmpty ? "(empty)" : snippet)
                    .font(.system(size: 11))
                    .lineLimit(2)

                HStack(spacing: 4) {
                    if highlight.note != nil {
                        Text("📝")
                            .font(.system(size: 9))
                        Text("Note attached")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No note")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
            }
        }
        .contextMenu {
            Button(highlight.note != nil ? "Edit Note" : "Add Note", action: onEditNote)
            Button("Remove Highlight", role: .destructive, action: onRemove)
        }
    }
}
