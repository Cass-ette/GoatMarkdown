import Foundation

enum TableColumnAlignment: Equatable {
    case left, center, right
}

enum MarkdownBlock: Equatable {
    case heading(level: Int, text: String)
    case paragraph(text: String)
    case unorderedList(items: [String])
    case orderedList(items: [String])
    case blockquote(text: String)
    case codeBlock(language: String?, code: String)
    case thematicBreak
    case table(headers: [String], alignments: [TableColumnAlignment], rows: [[String]])
    case image(alt: String, url: String)
    case link(text: String, url: String)
}
