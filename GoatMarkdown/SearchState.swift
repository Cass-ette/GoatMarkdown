import SwiftUI

@Observable
final class SearchState {
    var query = ""
    var isActive = false
    var currentMatchIndex = 0
    var matchCount = 0

    private var matches: [SearchMatch] = []

    func toggle() {
        isActive.toggle()
        if !isActive { clear() }
    }

    func clear() {
        query = ""
        matches = []
        matchCount = 0
        currentMatchIndex = 0
    }

    func search(in document: MarkdownDocument) {
        guard isActive, !query.isEmpty else {
            matches = []
            matchCount = 0
            currentMatchIndex = 0
            return
        }
        matches = findMatches(in: document, term: query.lowercased())
        matchCount = matches.count
        if currentMatchIndex >= matchCount { currentMatchIndex = 0 }
    }

    func nextMatch() {
        guard matchCount > 0 else { return }
        currentMatchIndex = (currentMatchIndex + 1) % matchCount
    }

    func previousMatch() {
        guard matchCount > 0 else { return }
        currentMatchIndex = (currentMatchIndex - 1 + matchCount) % matchCount
    }

    var currentMatch: SearchMatch? {
        guard matchCount > 0, currentMatchIndex < matches.count else { return nil }
        return matches[currentMatchIndex]
    }

    var currentMatchScrollID: String? {
        currentMatch?.scrollID
    }

    func isCurrentMatch(blockIndex: Int, textIndex: Int, range: Range<String.Index>) -> Bool {
        guard let match = currentMatch else { return false }
        return match.blockIndex == blockIndex && match.textIndex == textIndex && match.range == range
    }

    func isCurrentMatchInView(blockIndex: Int, textIndex: Int) -> Bool {
        guard let match = currentMatch else { return false }
        return match.blockIndex == blockIndex && match.textIndex == textIndex
    }

    func isAnyMatch(blockIndex: Int, textIndex: Int, range: Range<String.Index>) -> Bool {
        matches.contains { $0.blockIndex == blockIndex && $0.textIndex == textIndex && $0.range == range }
    }

    private func findMatches(in document: MarkdownDocument, term: String) -> [SearchMatch] {
        var results: [SearchMatch] = []
        for (blockIndex, block) in document.blocks.enumerated() {
            let plainTexts = extractSearchableTexts(from: block)
            for (textIndex, text) in plainTexts.enumerated() {
                let lower = text.lowercased()
                var start = lower.startIndex
                while start < lower.endIndex {
                    guard let range = lower.range(of: term, range: start..<lower.endIndex) else { break }
                    results.append(
                        SearchMatch(
                            blockIndex: blockIndex,
                            textIndex: textIndex,
                            range: range,
                            rangeStart: lower.distance(from: lower.startIndex, to: range.lowerBound),
                            rangeEnd: lower.distance(from: lower.startIndex, to: range.upperBound)
                        )
                    )
                    start = range.upperBound
                }
            }
        }
        return results
    }

    private func extractSearchableTexts(from block: MarkdownBlock) -> [String] {
        switch block {
        case .heading(_, let text): return [renderedPlainText(text)]
        case .paragraph(let text): return [renderedPlainText(text)]
        case .blockquote(let text): return [renderedPlainText(text)]
        case .unorderedList(let items): return items.map(renderedPlainText)
        case .orderedList(let items): return items.map(renderedPlainText)
        case .codeBlock(_, let code): return [code]
        case .table(let headers, _, let rows):
            return headers.map(renderedPlainText) + rows.flatMap { $0.map(renderedPlainText) }
        case .link(let text, _): return [renderedPlainText(text)]
        case .image(let alt, _): return [alt]
        case .thematicBreak: return []
        }
    }

    private func renderedPlainText(_ text: String) -> String {
        let attributed = (try? AttributedString(markdown: text)) ?? AttributedString(text)
        return String(attributed.characters)
    }
}

struct SearchMatch: Equatable {
    let blockIndex: Int
    let textIndex: Int
    let range: Range<String.Index>
    let rangeStart: Int
    let rangeEnd: Int

    var signature: String {
        "\(blockIndex)|\(textIndex)|\(rangeStart)|\(rangeEnd)"
    }

    var scrollID: String {
        "match-\(signature.replacingOccurrences(of: "|", with: "-"))"
    }
}
