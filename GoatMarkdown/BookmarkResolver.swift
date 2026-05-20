import Foundation

enum BookmarkResolver {
    static func signature(for block: MarkdownBlock) -> String {
        switch block {
        case .heading(let level, let text):
            return "h\(level)|\(text)"
        case .paragraph(let text):
            return "p|\(text.prefix(120))"
        case .blockquote(let text):
            return "bq|\(text.prefix(120))"
        case .unorderedList(let items):
            return "ul|\(items.prefix(3).joined(separator: "|"))"
        case .orderedList(let items):
            return "ol|\(items.prefix(3).joined(separator: "|"))"
        case .codeBlock(let lang, let code):
            return "cb|\(lang ?? "")|\(code.prefix(120))"
        case .thematicBreak:
            return "hr"
        case .table(let headers, _, _):
            return "tbl|\(headers.joined(separator: "|"))"
        case .image(let alt, let url):
            return "img|\(alt)|\(url)"
        case .link(let text, let url):
            return "lnk|\(text)|\(url)"
        }
    }

    static func resolveBlockIndex(signature: String, originalIndex: Int, in document: MarkdownDocument) -> Int? {
        if let matchIndex = document.blocks.firstIndex(where: { Self.signature(for: $0) == signature }) {
            return matchIndex
        }
        if document.blocks.indices.contains(originalIndex) {
            return originalIndex
        }
        return nil
    }

    static func makeBookmark(for block: MarkdownBlock, blockIndex: Int, isDefault: Bool) -> Bookmark {
        Bookmark(
            id: UUID(),
            blockIndex: blockIndex,
            blockSignature: signature(for: block),
            title: title(for: block),
            preview: preview(for: block),
            isDefault: isDefault,
            createdAt: Date()
        )
    }

    private static func title(for block: MarkdownBlock) -> String {
        switch block {
        case .heading(_, let text): return text
        case .paragraph(let text): return String(text.prefix(48))
        case .blockquote(let text): return String(text.prefix(48))
        case .unorderedList(let items): return items.first.map { String($0.prefix(48)) } ?? "List"
        case .orderedList(let items): return items.first.map { String($0.prefix(48)) } ?? "List"
        case .codeBlock(let lang, _): return lang.map { "Code (\($0))" } ?? "Code"
        case .thematicBreak: return "Divider"
        case .table(let headers, _, _): return headers.first ?? "Table"
        case .image(let alt, _): return alt.isEmpty ? "Image" : alt
        case .link(let text, _): return text
        }
    }

    private static func preview(for block: MarkdownBlock) -> String {
        switch block {
        case .heading(_, let text): return text
        case .paragraph(let text): return String(text.prefix(120))
        case .blockquote(let text): return String(text.prefix(120))
        case .unorderedList(let items): return items.prefix(3).joined(separator: " · ")
        case .orderedList(let items): return items.prefix(3).joined(separator: " · ")
        case .codeBlock(_, let code): return String(code.prefix(120))
        case .thematicBreak: return ""
        case .table(let headers, _, _): return headers.joined(separator: " | ")
        case .image(_, let url): return url
        case .link(_, let url): return url
        }
    }
}
