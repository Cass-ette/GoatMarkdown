import SwiftUI

struct MarkdownRenderer: View {
    let document: MarkdownDocument
    var theme: MarkdownTheme = MarkdownTheme()
    var searchText: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(document.blocks.enumerated()), id: \.offset) { _, block in
                    renderBlock(block)
                }
            }
            .frame(maxWidth: theme.contentMaxWidth)
            .padding(theme.contentPadding)
            .textSelection(.enabled)
        }
    }

    // MARK: - Inline Markdown

    private func renderInlineMarkdown(_ text: String) -> AttributedString {
        if var attributed = try? AttributedString(markdown: text) {
            if !searchText.isEmpty {
                highlightSearch(in: &attributed)
            }
            return attributed
        }
        var fallback = AttributedString(text)
        if !searchText.isEmpty {
            highlightSearch(in: &fallback)
        }
        return fallback
    }

    private func highlightSearch(in attributed: inout AttributedString) {
        let plain = String(attributed.characters)
        let lower = plain.lowercased()
        let searchLower = searchText.lowercased()
        var start = lower.startIndex
        while start < lower.endIndex {
            guard let range = lower.range(of: searchLower, range: start..<lower.endIndex) else { break }
            let attrRange = Range(range, in: attributed)!
            attributed[attrRange].backgroundColor = Color(nsColor: .findHighlightColor)
            start = range.upperBound
        }
    }

    @ViewBuilder
    private func renderBlock(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            Text((try? AttributedString(markdown: text)) ?? AttributedString(text))
                .font(theme.headingFonts[level] ?? .headline)
                .foregroundStyle(theme.headingColor)

        case .paragraph(let text):
            Text(renderInlineMarkdown(text))
                .font(theme.bodyFont)
                .foregroundStyle(theme.bodyColor)

        case .unorderedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text(theme.listItemBullet)
                            .font(theme.bodyFont)
                            .foregroundStyle(theme.bodyColor)
                        Text(renderInlineMarkdown(item))
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
                        Text(renderInlineMarkdown(item))
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
                Text(renderInlineMarkdown(text))
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
                    Text(renderInlineMarkdown(headers[col]))
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
                        Text(renderInlineMarkdown(cellText))
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
