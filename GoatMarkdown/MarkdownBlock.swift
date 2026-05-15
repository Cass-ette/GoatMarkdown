import Foundation

enum MarkdownBlock: Equatable {
    case heading(level: Int, text: String)
    case paragraph(text: String)
    case unorderedList(items: [String])
    case orderedList(items: [String])
    case blockquote(text: String)
    case codeBlock(language: String?, code: String)
    case thematicBreak
}
