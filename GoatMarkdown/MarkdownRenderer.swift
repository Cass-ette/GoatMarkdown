import SwiftUI

struct MarkdownRenderer: View {
    let document: MarkdownDocument
    var theme: MarkdownTheme = MarkdownTheme()
    var searchState: SearchState?
    var pendingScrollBlockIndex: Binding<Int?> = .constant(nil)
    var onToggleBookmark: ((Int) -> Void)?
    var onToggleDefaultBookmark: ((Int) -> Void)?
    var hasBookmark: ((Int) -> Bool)?
    var isDefaultBookmark: ((Int) -> Bool)?

    @State private var hoveringBlockIndex: Int?
    private static var inlineCache: [String: AttributedString] = [:]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(document.blocks.enumerated()), id: \.element.id) { index, block in
                        BlockRow(
                            blockIndex: index,
                            hasBookmark: hasBookmark?(index) ?? false,
                            isDefaultBookmark: isDefaultBookmark?(index) ?? false,
                            isHovering: hoveringBlockIndex == index,
                            onToggleBookmark: onToggleBookmark,
                            onToggleDefaultBookmark: onToggleDefaultBookmark,
                            onHoverChange: { hovering in
                                hoveringBlockIndex = hovering ? index : nil
                            }
                        ) {
                            renderBlock(block, blockIndex: index)
                        }
                        .id("block-\(index)")
                    }
                }
                .frame(maxWidth: theme.contentMaxWidth)
                .padding(theme.contentPadding)
                .textSelection(.enabled)
            }
            .onChange(of: searchState?.currentMatchIndex ?? 0) { _, _ in
                scrollToCurrentMatch(with: proxy)
            }
            .onChange(of: searchState?.matchCount ?? 0) { _, newCount in
                if newCount > 0 {
                    scrollToCurrentMatch(with: proxy)
                }
            }
            .onChange(of: pendingScrollBlockIndex.wrappedValue) { _, newValue in
                guard let blockIndex = newValue else { return }
                withAnimation {
                    proxy.scrollTo("block-\(blockIndex)", anchor: .top)
                }
                pendingScrollBlockIndex.wrappedValue = nil
            }
            .onAppear {
                if let blockIndex = pendingScrollBlockIndex.wrappedValue {
                    DispatchQueue.main.async {
                        proxy.scrollTo("block-\(blockIndex)", anchor: .top)
                        pendingScrollBlockIndex.wrappedValue = nil
                    }
                }
            }
        }
    }

    private func scrollToCurrentMatch(with proxy: ScrollViewProxy) {
        guard let match = searchState?.currentMatch else { return }
        withAnimation {
            proxy.scrollTo("block-\(match.blockIndex)", anchor: .center)
        }
    }

    private func matchScrollID(for blockIndex: Int, textIndex: Int) -> String? {
        if searchState?.isCurrentMatchInView(blockIndex: blockIndex, textIndex: textIndex) == true {
            return searchState?.currentMatchScrollID
        }
        return nil
    }

    // MARK: - Inline Markdown (cached)

    private func cachedInline(_ text: String, inBlock blockIndex: Int? = nil, textIndex: Int = 0) -> AttributedString {
        let cacheKey: String
        if let query = searchState?.query, !query.isEmpty {
            let currentMatchSignature = searchState?.currentMatch?.signature ?? "none"
            cacheKey = "\(query)|\(blockIndex.map(String.init) ?? "none")|\(textIndex)|\(currentMatchSignature)\n\(text)"
        } else {
            cacheKey = text
        }
        if let cached = Self.inlineCache[cacheKey] { return cached }

        var result = (try? AttributedString(markdown: text)) ?? AttributedString(text)

        if let query = searchState?.query, !query.isEmpty {
            highlightWords(in: &result, query: query, blockIndex: blockIndex, textIndex: textIndex)
        }

        Self.inlineCache[cacheKey] = result
        if Self.inlineCache.count > 2000 { Self.inlineCache.removeAll() }
        return result
    }

    private func highlightWords(
        in attributed: inout AttributedString,
        query: String,
        blockIndex: Int?,
        textIndex: Int
    ) {
        let plain = String(attributed.characters)
        let lower = plain.lowercased()
        let searchLower = query.lowercased()
        var start = lower.startIndex
        while start < lower.endIndex {
            guard let range = lower.range(of: searchLower, range: start..<lower.endIndex) else { break }
            if let attrRange = Range(range, in: attributed) {
                if let blockIndex, searchState?.isCurrentMatch(blockIndex: blockIndex, textIndex: textIndex, range: range) == true {
                    attributed[attrRange].backgroundColor = Color.orange
                } else {
                    attributed[attrRange].backgroundColor = Color.orange.opacity(0.25)
                }
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
                .id(matchScrollID(for: blockIndex, textIndex: 0))

        case .unorderedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { itemIndex, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text(theme.listItemBullet)
                            .font(theme.bodyFont)
                            .foregroundStyle(theme.bodyColor)
                        Text(cachedInline(item, inBlock: blockIndex, textIndex: itemIndex))
                            .font(theme.bodyFont)
                            .foregroundStyle(theme.bodyColor)
                            .id(matchScrollID(for: blockIndex, textIndex: itemIndex))
                    }
                }
            }

        case .orderedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { itemIndex, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(itemIndex + 1).")
                            .font(theme.bodyFont)
                            .foregroundStyle(theme.bodyColor)
                            .frame(width: 28, alignment: .trailing)
                        Text(cachedInline(item, inBlock: blockIndex, textIndex: itemIndex))
                            .font(theme.bodyFont)
                            .foregroundStyle(theme.bodyColor)
                            .id(matchScrollID(for: blockIndex, textIndex: itemIndex))
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
                    .id(matchScrollID(for: blockIndex, textIndex: 0))
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
            renderTable(headers: headers, alignments: alignments, rows: rows, blockIndex: blockIndex)

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

    private func renderTable(headers: [String], alignments: [TableColumnAlignment], rows: [[String]], blockIndex: Int) -> some View {
        let colCount = headers.count
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                ForEach(0..<colCount, id: \.self) { col in
                    Text(cachedInline(headers[col], inBlock: blockIndex, textIndex: col))
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
                        Text(cachedInline(cellText, inBlock: blockIndex, textIndex: textIndexForTableCell(row: rowIdx, column: col, headers: headers, rows: rows)))
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

    private func textIndexForTableCell(row: Int, column: Int, headers: [String], rows: [[String]]) -> Int {
        let precedingCells = rows.prefix(row).reduce(0) { $0 + $1.count }
        return headers.count + precedingCells + column
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

private struct BlockRow<Content: View>: View {
    let blockIndex: Int
    let hasBookmark: Bool
    let isDefaultBookmark: Bool
    let isHovering: Bool
    let onToggleBookmark: ((Int) -> Void)?
    let onToggleDefaultBookmark: ((Int) -> Void)?
    let onHoverChange: (Bool) -> Void
    let content: () -> Content

    init(
        blockIndex: Int,
        hasBookmark: Bool,
        isDefaultBookmark: Bool,
        isHovering: Bool,
        onToggleBookmark: ((Int) -> Void)?,
        onToggleDefaultBookmark: ((Int) -> Void)?,
        onHoverChange: @escaping (Bool) -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.blockIndex = blockIndex
        self.hasBookmark = hasBookmark
        self.isDefaultBookmark = isDefaultBookmark
        self.isHovering = isHovering
        self.onToggleBookmark = onToggleBookmark
        self.onToggleDefaultBookmark = onToggleDefaultBookmark
        self.onHoverChange = onHoverChange
        self.content = content
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            BookmarkGutterButton(
                blockIndex: blockIndex,
                hasBookmark: hasBookmark,
                isDefaultBookmark: isDefaultBookmark,
                isHovering: isHovering,
                onToggleBookmark: onToggleBookmark,
                onToggleDefaultBookmark: onToggleDefaultBookmark
            )
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onHover { hovering in
            onHoverChange(hovering)
        }
    }
}

private struct BookmarkGutterButton: View {
    let blockIndex: Int
    let hasBookmark: Bool
    let isDefaultBookmark: Bool
    let isHovering: Bool
    let onToggleBookmark: ((Int) -> Void)?
    let onToggleDefaultBookmark: ((Int) -> Void)?

    var body: some View {
        Button {
            if NSEvent.modifierFlags.contains(.shift) {
                onToggleDefaultBookmark?(blockIndex)
            } else {
                onToggleBookmark?(blockIndex)
            }
        } label: {
            Image(systemName: iconName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
                .opacity(opacity)
        }
        .buttonStyle(.plain)
        .help(helpText)
        .contextMenu {
            Button(hasBookmark ? "Remove bookmark" : "Add bookmark") {
                onToggleBookmark?(blockIndex)
            }
            Button(isDefaultBookmark ? "Unset auto-open default" : "Set as auto-open default") {
                onToggleDefaultBookmark?(blockIndex)
            }
        }
        .frame(width: 22)
    }

    private var opacity: Double {
        if hasBookmark { return 1.0 }
        if isHovering { return 1.0 }
        return 0.18
    }

    private var iconName: String {
        if isDefaultBookmark { return "bookmark.fill" }
        if hasBookmark { return "bookmark.fill" }
        return "bookmark"
    }

    private var iconColor: Color {
        if isDefaultBookmark { return .yellow }
        if hasBookmark { return .accentColor }
        return .secondary
    }

    private var helpText: String {
        if hasBookmark {
            return "Click: remove bookmark · Shift+Click: toggle auto-open default"
        }
        return "Click: add bookmark · Shift+Click: set as auto-open default"
    }
}
