import SwiftUI

struct MarkdownRenderer: View {
    let document: MarkdownDocument
    var theme: MarkdownTheme = MarkdownTheme()
    var searchState: SearchState?

    private static var inlineCache: [String: AttributedString] = [:]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(document.blocks.enumerated()), id: \.element.id) { index, block in
                        renderBlock(block, blockIndex: index)
                            .id("block-\(index)")
                    }
                }
                .frame(maxWidth: theme.contentMaxWidth)
                .padding(theme.contentPadding)
                .textSelection(.enabled)
            }
            .onChange(of: searchState?.currentMatchIndex ?? 0) { _, _ in
                if let match = searchState?.currentMatch {
                    withAnimation {
                        proxy.scrollTo("block-\(match.blockIndex)", anchor: .center)
                    }
                }
            }
            .onChange(of: searchState?.matchCount ?? 0) { _, newCount in
                if newCount > 0, let match = searchState?.currentMatch {
                    withAnimation {
                        proxy.scrollTo("block-\(match.blockIndex)", anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Inline Markdown (cached)

    private func cachedInline(_ text: String, inBlock blockIndex: Int? = nil) -> AttributedString {
        let isCurrent = blockIndex != nil && blockIndex == searchState?.currentMatch?.blockIndex
        let cacheKey: String
        if let query = searchState?.query, !query.isEmpty {
            cacheKey = "\(query)|\(isCurrent)\n\(text)"
        } else {
            cacheKey = text
        }
        if let cached = Self.inlineCache[cacheKey] { return cached }

        var result = (try? AttributedString(markdown: text)) ?? AttributedString(text)

        if let query = searchState?.query, !query.isEmpty {
            if isCurrent {
                highlightCurrentWords(in: &result, query: query)
            } else {
                highlightWords(in: &result, query: query)
            }
        }

        Self.inlineCache[cacheKey] = result
        if Self.inlineCache.count > 2000 { Self.inlineCache.removeAll() }
        return result
    }

    private func highlightWords(in attributed: inout AttributedString, query: String) {
        highlightWords(in: &attributed, query: query, isCurrentBlock: false)
    }

    private func highlightCurrentWords(in attributed: inout AttributedString, query: String) {
        highlightWords(in: &attributed, query: query, isCurrentBlock: true)
    }

    private func highlightWords(in attributed: inout AttributedString, query: String, isCurrentBlock: Bool) {
        let plain = String(attributed.characters)
        let lower = plain.lowercased()
        let searchLower = query.lowercased()
        let normalColor = Color.orange.opacity(0.3)
        let currentColor = Color.orange.opacity(0.7)
        var start = lower.startIndex
        while start < lower.endIndex {
            guard let range = lower.range(of: searchLower, range: start..<lower.endIndex) else { break }
            if let attrRange = Range(range, in: attributed) {
                attributed[attrRange].backgroundColor = isCurrentBlock ? currentColor : normalColor
            }
            start = range.upperBound
        }
    }

    // MARK: - Block rendering

    @ViewBuilder
    private func renderBlock(_ block: MarkdownBlock, blockIndex: Int) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(text)
                .font(theme.headingFonts[level] ?? .headline)
                .foregroundStyle(theme.headingColor)

        case .paragraph(let text):
            Text(cachedInline(text, inBlock: blockIndex))
                .font(theme.bodyFont)
                .foregroundStyle(theme.bodyColor)

        case .unorderedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text(theme.listItemBullet)
                            .font(theme.bodyFont)
                            .foregroundStyle(theme.bodyColor)
                        Text(cachedInline(item, inBlock: blockIndex))
                            .font(theme.bodyFont)
                            .foregroundStyle(theme.bodyColor)
                    }
                }
            }

        case .orderedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .font(theme.bodyFont)
                            .foregroundStyle(theme.bodyColor)
                            .frame(width: 28, alignment: .trailing)
                        Text(cachedInline(item, inBlock: blockIndex))
                            .font(theme.bodyFont)
                            .foregroundStyle(theme.bodyColor)
                    }
                }
            }

        case .blockquote(let text):
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.quoteBarColor)
                    .frame(width: 4)
                Text(cachedInline(text, inBlock: blockIndex))
                    .font(theme.bodyFont)
                    .foregroundStyle(theme.quoteColor)
                    .padding(.leading, 12)
                    .padding(.vertical, 4)
            }

        case .codeBlock(let language, let code):
            VStack(alignment: .leading, spacing: 0) {
                if let language {
                    Text(language)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                }
                Text(code)
                    .font(theme.codeFont)
                    .foregroundStyle(theme.bodyColor)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(theme.codeBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))

        case .thematicBreak:
            Divider()
                .background(theme.hrColor)
                .padding(.vertical, 4)

        case .table(let headers, let alignments, let rows):
            renderTable(headers: headers, alignments: alignments, rows: rows)

        case .image(let alt, let url):
            renderImage(alt: alt, url: url)

        case .link(let text, let url):
            if let linkURL = URL(string: url) {
                Link(destination: linkURL) {
                    Text(text)
                        .font(theme.bodyFont)
                        .foregroundStyle(Color.accentColor)
                        .underline()
                }
            } else {
                Text(text)
                    .font(theme.bodyFont)
                    .foregroundStyle(theme.bodyColor)
            }
        }
    }

    // MARK: - Table

    private func renderTable(headers: [String], alignments: [TableColumnAlignment], rows: [[String]]) -> some View {
        let colCount = headers.count
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                ForEach(0..<colCount, id: \.self) { col in
                    Text(cachedInline(headers[col]))
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: alignmentForColumn(col, alignments: alignments))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .lineLimit(1)
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))

            ForEach(0..<rows.count, id: \.self) { rowIdx in
                HStack(spacing: 0) {
                    ForEach(0..<colCount, id: \.self) { col in
                        let cellText = col < rows[rowIdx].count ? rows[rowIdx][col] : ""
                        Text(cachedInline(cellText))
                            .font(theme.bodyFont)
                            .frame(maxWidth: .infinity, alignment: alignmentForColumn(col, alignments: alignments))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                    }
                }
                if rowIdx < rows.count - 1 {
                    Divider()
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }

    private func alignmentForColumn(_ index: Int, alignments: [TableColumnAlignment]) -> Alignment {
        guard index < alignments.count else { return .leading }
        switch alignments[index] {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }

    // MARK: - Image

    private func renderImage(alt: String, url: String) -> some View {
        Group {
            if url.hasPrefix("http"), let imageURL = URL(string: url) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure:
                        Text(alt)
                            .font(theme.bodyFont)
                            .foregroundStyle(.secondary)
                    default:
                        ProgressView()
                    }
                }
            } else {
                let fileURL = URL(fileURLWithPath: url)
                if let nsImage = NSImage(contentsOf: fileURL) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Text(alt)
                        .font(theme.bodyFont)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
