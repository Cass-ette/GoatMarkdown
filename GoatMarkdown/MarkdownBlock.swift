import Foundation

enum TableColumnAlignment: Equatable {
    case left, center, right
}

enum MarkdownBlock: Equatable, Identifiable {
    var id: String {
        switch self {
        case .heading(let l, let t): return "h\(l)-\(t)"
        case .paragraph(let t): return "p-\(t.prefix(64))"
        case .unorderedList(let items): return "ul-\(items.joined())"
        case .orderedList(let items): return "ol-\(items.joined())"
        case .blockquote(let t): return "bq-\(t.prefix(64))"
        case .codeBlock(let lang, let code): return "cb-\(lang ?? "")-\(code.prefix(64))"
        case .thematicBreak: return "hr"
        case .table(let h, _, _): return "tbl-\(h.joined())"
        case .image(let alt, let url): return "img-\(alt)-\(url)"
        case .link(let t, let url): return "lnk-\(t)-\(url)"
        }
    }


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
