import Foundation

enum MarkdownParser {
    static func parse(_ text: String) -> MarkdownDocument {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = []
        var i = 0

        while i < lines.count {
            let line = lines[i]

            // Blank line
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                i += 1
                continue
            }

            // Thematic break: ---, ***, ___
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if isThematicBreak(trimmed) {
                blocks.append(.thematicBreak)
                i += 1
                continue
            }

            // ATX heading: # ... ######
            if let heading = parseHeading(trimmed) {
                blocks.append(heading)
                i += 1
                continue
            }

            // Fenced code block
            if let fenceInfo = parseFenceOpener(trimmed) {
                let (codeBlock, newIndex) = collectFencedCodeBlock(lines: lines, start: i + 1, fenceChar: fenceInfo.char, indent: fenceInfo.indent)
                blocks.append(.codeBlock(language: fenceInfo.language, code: codeBlock))
                i = newIndex
                continue
            }

            // Blockquote
            if trimmed.hasPrefix(">") {
                var text: [String] = []
                while i < lines.count {
                    let l = lines[i].trimmingCharacters(in: .whitespaces)
                    if l.hasPrefix(">") {
                        text.append(String(l.dropFirst()).trimmingCharacters(in: .whitespaces))
                        i += 1
                    } else if !l.isEmpty {
                        text.append(l)
                        i += 1
                    } else {
                        break
                    }
                }
                blocks.append(.blockquote(text: text.joined(separator: " ")))
                continue
            }

            // Unordered list: -, *, +
            if isUnorderedListItem(trimmed) {
                let (items, newIndex) = collectUnorderedList(lines: lines, start: i)
                blocks.append(.unorderedList(items: items))
                i = newIndex
                continue
            }

            // Ordered list: 1.
            if let _ = parseOrderedListItem(trimmed) {
                let (items, newIndex) = collectOrderedList(lines: lines, start: i)
                blocks.append(.orderedList(items: items))
                i = newIndex
                continue
            }

            // Image: ![alt](url) on its own line
            if let image = parseStandaloneImage(trimmed) {
                blocks.append(image)
                i += 1
                continue
            }

            // Standalone link: [text](url) on its own line
            if let link = parseStandaloneLink(trimmed) {
                blocks.append(link)
                i += 1
                continue
            }

            // Table: header row + separator row
            if let table = tryParseTable(lines: lines, currentIndex: i) {
                blocks.append(table.block)
                i = table.nextIndex
                continue
            }

            // Paragraph
            var paraLines: [String] = []
            while i < lines.count {
                let l = lines[i]
                if l.trimmingCharacters(in: .whitespaces).isEmpty { break }
                paraLines.append(l.trimmingCharacters(in: .whitespaces))
                i += 1
            }
            if !paraLines.isEmpty {
                blocks.append(.paragraph(text: paraLines.joined(separator: " ")))
            }
        }

        return MarkdownDocument(blocks: blocks, rawText: text)
    }

    // MARK: - Heading

    private static func parseHeading(_ line: String) -> MarkdownBlock? {
        var count = 0
        for ch in line {
            if ch == "#" { count += 1 } else { break }
        }
        guard count >= 1 && count <= 6 else { return nil }
        let rest = line.dropFirst(count).trimmingCharacters(in: .whitespaces)
        return .heading(level: count, text: rest)
    }

    // MARK: - Thematic break

    private static func isThematicBreak(_ line: String) -> Bool {
        let chars = CharacterSet(charactersIn: "-*_")
        let filtered = line.unicodeScalars.filter { !chars.contains($0) && !CharacterSet.whitespaces.contains($0) }
        guard filtered.isEmpty else { return false }
        let nonSpace = line.unicodeScalars.filter { !CharacterSet.whitespaces.contains($0) }
        return nonSpace.count >= 3
    }

    // MARK: - Fenced code block

    private struct FenceInfo {
        let char: Character
        let indent: Int
        let language: String?
    }

    private static func parseFenceOpener(_ line: String) -> FenceInfo? {
        let fenceChars: [Character] = ["`", "~"]
        for ch in fenceChars {
            var count = 0
            for c in line {
                if c == ch { count += 1 } else { break }
            }
            if count >= 3 {
                let lang = line.dropFirst(count).trimmingCharacters(in: .whitespaces)
                let indent = line.prefix(while: { $0 == " " }).count
                return FenceInfo(char: ch, indent: indent, language: lang.isEmpty ? nil : lang)
            }
        }
        return nil
    }

    private static func collectFencedCodeBlock(lines: [String], start: Int, fenceChar: Character, indent: Int) -> (String, Int) {
        var codeLines: [String] = []
        var i = start
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if isClosingFence(trimmed, char: fenceChar) { return (codeLines.joined(separator: "\n"), i + 1) }
            let content = line.count > indent ? String(line.dropFirst(min(indent, line.prefix(while: { $0 == " " }).count))) : line
            codeLines.append(content)
            i += 1
        }
        return (codeLines.joined(separator: "\n"), i)
    }

    private static func isClosingFence(_ line: String, char: Character) -> Bool {
        var count = 0
        for c in line {
            if c == char { count += 1 } else { break }
        }
        guard count >= 3 else { return false }
        let rest = line.dropFirst(count).trimmingCharacters(in: .whitespaces)
        return rest.isEmpty
    }

    // MARK: - Lists

    private static func isUnorderedListItem(_ line: String) -> Bool {
        guard let first = line.first else { return false }
        guard "-*+".contains(first) else { return false }
        let rest = line.dropFirst()
        return rest.first?.isWhitespace == true || rest.isEmpty
    }

    private static func collectUnorderedList(lines: [String], start: Int) -> ([String], Int) {
        var items: [String] = []
        var i = start
        while i < lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if isUnorderedListItem(trimmed) {
                items.append(String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces))
                i += 1
            } else {
                break
            }
        }
        return (items, i)
    }

    private static func parseOrderedListItem(_ line: String) -> Int? {
        var digits = ""
        for ch in line {
            if ch.isNumber { digits.append(ch) } else { break }
        }
        guard !digits.isEmpty, let dotIndex = line.index(line.startIndex, offsetBy: digits.count, limitedBy: line.endIndex) else { return nil }
        guard dotIndex < line.endIndex, line[dotIndex] == "." else { return nil }
        let afterDot = line.index(after: dotIndex)
        guard afterDot < line.endIndex, line[afterDot].isWhitespace else { return nil }
        return Int(digits)
    }

    private static func collectOrderedList(lines: [String], start: Int) -> ([String], Int) {
        var items: [String] = []
        var i = start
        while i < lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if let _ = parseOrderedListItem(trimmed) {
                var text = trimmed
                if let dotRange = text.range(of: ".") {
                    text = String(text[dotRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                }
                items.append(text)
                i += 1
            } else {
                break
            }
        }
        return (items, i)
    }

    // MARK: - Image & Link

    private static func parseStandaloneImage(_ line: String) -> MarkdownBlock? {
        guard line.hasPrefix("![") && line.contains("](") && line.hasSuffix(")") else { return nil }
        return parseImageOrLink(line: line, prefix: "!")
    }

    private static func parseStandaloneLink(_ line: String) -> MarkdownBlock? {
        guard line.hasPrefix("[") && line.contains("](") && line.hasSuffix(")") else { return nil }
        guard !line.hasPrefix("![") else { return nil }
        return parseImageOrLink(line: line, prefix: "")
    }

    private static func parseImageOrLink(line: String, prefix: String) -> MarkdownBlock? {
        let openBracket = prefix + "["
        guard line.hasPrefix(openBracket) else { return nil }
        let afterOpen = line.index(line.startIndex, offsetBy: openBracket.count)
        guard let closeBracket = line[afterOpen...].firstIndex(of: "]") else { return nil }
        let text = String(line[afterOpen..<closeBracket])
        let afterClose = line.index(after: closeBracket)
        guard afterClose < line.endIndex, line[afterClose] == "(" else { return nil }
        let urlStart = line.index(after: afterClose)
        guard line.hasSuffix(")") else { return nil }
        let urlEnd = line.index(before: line.endIndex)
        let url = String(line[urlStart..<urlEnd]).trimmingCharacters(in: .whitespaces)
        guard !url.isEmpty else { return nil }

        if prefix == "!" {
            return .image(alt: text, url: url)
        } else {
            return .link(text: text, url: url)
        }
    }

    // MARK: - Table

    private struct TableResult {
        let block: MarkdownBlock
        let nextIndex: Int
    }

    private static func tryParseTable(lines: [String], currentIndex: Int) -> TableResult? {
        guard currentIndex + 1 < lines.count else { return nil }
        let headerLine = lines[currentIndex].trimmingCharacters(in: .whitespaces)
        let sepLine = lines[currentIndex + 1].trimmingCharacters(in: .whitespaces)
        guard isPipeDelimited(headerLine), isTableSeparator(sepLine) else { return nil }

        let headers = parsePipeRow(headerLine)
        let alignments = parseAlignments(sepLine)
        guard headers.count == alignments.count else { return nil }

        var rows: [[String]] = []
        var i = currentIndex + 2
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.isEmpty || !isPipeDelimited(line) { break }
            let cells = parsePipeRow(line)
            rows.append(cells)
            i += 1
        }

        return TableResult(
            block: .table(headers: headers, alignments: alignments, rows: rows),
            nextIndex: i
        )
    }

    private static func isPipeDelimited(_ line: String) -> Bool {
        line.contains("|")
    }

    private static func isTableSeparator(_ line: String) -> Bool {
        let stripped = line.trimmingCharacters(in: CharacterSet(charactersIn: " |:-"))
        guard stripped.isEmpty else { return false }
        let cols = parsePipeRow(line)
        return cols.allSatisfy { cell in
            let trimmed = cell.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("-") || trimmed.hasPrefix(":") else { return false }
            let cleaned = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: ":-"))
            return cleaned.allSatisfy { $0 == "-" }
        }
    }

    private static func parsePipeRow(_ line: String) -> [String] {
        var cells = line.components(separatedBy: "|")
        if cells.first?.trimmingCharacters(in: .whitespaces).isEmpty == true { cells.removeFirst() }
        if cells.last?.trimmingCharacters(in: .whitespaces).isEmpty == true { cells.removeLast() }
        return cells.map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func parseAlignments(_ line: String) -> [TableColumnAlignment] {
        parsePipeRow(line).map { cell in
            let trimmed = cell.trimmingCharacters(in: .whitespaces)
            let left = trimmed.hasPrefix(":")
            let right = trimmed.hasSuffix(":")
            if left && right { return .center }
            if right { return .right }
            return .left
        }
    }
}
