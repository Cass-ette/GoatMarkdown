# Highlighter Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a macOS-native text highlighter to GoatMarkdown that lets users mark text with 5 preset colors via `Cmd+Shift+H` keyboard shortcut, with persistence via JSON sidecar files.

**Architecture:** 
- `HighlightColor` enum + `Highlight` data model
- `HighlightStore` (Codable, UserDefaults-backed like `BookmarkStore`)
- `HighlightState` (`@Observable`, in-memory state per document)
- `HighlightState` integrated into `MarkdownReaderState`
- `MarkdownRenderer.cachedText()` extended to apply background colors via `AttributedString.backgroundColor`
- `Cmd+Shift+H` keyboard handler in `ContentView` reads current text selection, calls `highlightState.add()`

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit, Xcode 16, macOS 15.0+

---

## File Structure

**New files:**
- `GoatMarkdown/HighlightColor.swift` — enum + `swiftUIColor` accessor
- `GoatMarkdown/Highlight.swift` — `Highlight` struct
- `GoatMarkdown/HighlightState.swift` — `@Observable` state class with add/remove/toggle/find
- `GoatMarkdownTests/HighlightStateTests.swift` — unit tests for state logic
- `GoatMarkdownTests/HighlightStoreTests.swift` — unit tests for persistence

**Modified files:**
- `GoatMarkdown/Bookmark.swift` — add `HighlightStore` class (keep near `BookmarkStore` per existing pattern)
- `GoatMarkdown/MarkdownReaderState.swift` — add `HighlightState` integration, load on file select
- `GoatMarkdown/MarkdownRenderer.swift` — accept `highlightState` parameter, apply background colors in `cachedText()`
- `GoatMarkdown/ContentView.swift` — pass `highlightState` to `MarkdownRenderer`, wire `Cmd+Shift+H` keyboard shortcut
- `README.md` — document highlighter feature + `Cmd+Shift+H` shortcut

**Out of scope (deferred to future iteration):**
- Selection popover UI (requires NSTextView bridging — too much MVP risk)
- `HighlightColorPicker.swift`
- Color button UI for changing highlight color (MVP = yellow only via keyboard)

---

## Chunk 1: Data Model & Persistence (Tasks 1-2)

### Task 1: HighlightColor enum

**Files:**
- Create: `GoatMarkdown/HighlightColor.swift`

- [ ] **Step 1: Create HighlightColor enum file**

```swift
import SwiftUI

enum HighlightColor: String, Codable, CaseIterable, Equatable {
    case yellow
    case green
    case blue
    case pink
    case purple

    var swiftUIColor: Color {
        switch self {
        case .yellow: return Color.yellow.opacity(0.35)
        case .green: return Color.green.opacity(0.35)
        case .blue: return Color.blue.opacity(0.35)
        case .pink: return Color.pink.opacity(0.35)
        case .purple: return Color.purple.opacity(0.35)
        }
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodegen generate && xcodebuild build -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -configuration Debug`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add GoatMarkdown/HighlightColor.swift
git commit -m "feat: add HighlightColor enum with 5 preset colors"
```

---

### Task 2: Highlight struct

**Files:**
- Create: `GoatMarkdown/Highlight.swift`

- [ ] **Step 1: Create Highlight struct file**

```swift
import Foundation

struct Highlight: Equatable, Codable, Identifiable {
    let id: UUID
    let blockIndex: Int
    let textIndex: Int
    let rangeStart: Int
    let rangeEnd: Int
    let color: HighlightColor
    let createdAt: Date

    init(
        id: UUID = UUID(),
        blockIndex: Int,
        textIndex: Int,
        rangeStart: Int,
        rangeEnd: Int,
        color: HighlightColor,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.blockIndex = blockIndex
        self.textIndex = textIndex
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
        self.color = color
        self.createdAt = createdAt
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild build -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -configuration Debug`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add GoatMarkdown/Highlight.swift
git commit -m "feat: add Highlight data model"
```

---

## Chunk 2: HighlightStore (Tasks 3-4)

### Task 3: HighlightStore class

**Files:**
- Modify: `GoatMarkdown/Bookmark.swift:73` (append after BookmarkStore closing brace)

- [ ] **Step 1: Append HighlightStore class to Bookmark.swift**

Append at end of `GoatMarkdown/Bookmark.swift`:

```swift

@Observable
final class HighlightStore {
    private let defaults: UserDefaults
    private static let storageKey = "highlights.byFilePath.v1"

    private var byFilePath: [String: [Highlight]] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([String: [Highlight]].self, from: data) {
            byFilePath = decoded
        }
    }

    func highlights(for filePath: String) -> [Highlight] {
        byFilePath[filePath] ?? []
    }

    func setHighlights(_ highlights: [Highlight], for filePath: String) {
        if highlights.isEmpty {
            byFilePath.removeValue(forKey: filePath)
        } else {
            byFilePath[filePath] = highlights
        }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(byFilePath) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild build -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -configuration Debug`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add GoatMarkdown/Bookmark.swift
git commit -m "feat: add HighlightStore for sidecar persistence"
```

---

### Task 4: HighlightStore unit tests (TDD)

**Files:**
- Create: `GoatMarkdownTests/HighlightStoreTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import Foundation
import XCTest
@testable import GoatMarkdown

final class HighlightStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "HighlightStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testEmptyStoreReturnsEmpty() {
        let store = HighlightStore(defaults: defaults)
        XCTAssertEqual(store.highlights(for: "/tmp/A.md"), [])
    }

    func testSetHighlightsPersistsAcrossInstances() {
        let store = HighlightStore(defaults: defaults)
        let highlight = Highlight(
            blockIndex: 0,
            textIndex: 0,
            rangeStart: 5,
            rangeEnd: 10,
            color: .yellow
        )
        store.setHighlights([highlight], for: "/tmp/A.md")

        let reloaded = HighlightStore(defaults: defaults)
        XCTAssertEqual(reloaded.highlights(for: "/tmp/A.md"), [highlight])
    }

    func testSetEmptyHighlightsRemovesFileEntry() {
        let store = HighlightStore(defaults: defaults)
        store.setHighlights([Highlight(blockIndex: 0, textIndex: 0, rangeStart: 0, rangeEnd: 5, color: .green)], for: "/tmp/A.md")
        store.setHighlights([], for: "/tmp/A.md")

        XCTAssertEqual(store.highlights(for: "/tmp/A.md"), [])
    }

    func testCorruptedJSONStartsEmpty() {
        defaults.set(Data("not valid json".utf8), forKey: "highlights.byFilePath.v1")
        let store = HighlightStore(defaults: defaults)
        XCTAssertEqual(store.highlights(for: "/tmp/A.md"), [])
    }
}
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `xcodebuild test -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -only-testing:GoatMarkdownTests/HighlightStoreTests`
Expected: 4 tests passed

- [ ] **Step 3: Commit**

```bash
git add GoatMarkdownTests/HighlightStoreTests.swift
git commit -m "test: add HighlightStore unit tests"
```

---

## Chunk 3: HighlightState (Tasks 5-6)

### Task 5: HighlightState class

**Files:**
- Create: `GoatMarkdown/HighlightState.swift`

- [ ] **Step 1: Create HighlightState file**

```swift
import Foundation

@Observable
final class HighlightState {
    private(set) var highlights: [Highlight] = []

    func add(_ highlight: Highlight) {
        highlights.removeAll { $0.id == highlight.id }
        highlights.append(highlight)
    }

    func remove(id: UUID) {
        highlights.removeAll { $0.id == id }
    }

    func find(blockIndex: Int, textIndex: Int, range: Range<Int>) -> Highlight? {
        highlights.first { existing in
            existing.blockIndex == blockIndex
            && existing.textIndex == textIndex
            && existing.rangeStart < range.upperBound
            && existing.rangeEnd > range.lowerBound
        }
    }

    func toggle(blockIndex: Int, textIndex: Int, range: Range<Int>, color: HighlightColor = .yellow) -> Highlight? {
        if let existing = find(blockIndex: blockIndex, textIndex: textIndex, range: range) {
            remove(id: existing.id)
            return nil
        }
        let new = Highlight(
            blockIndex: blockIndex,
            textIndex: textIndex,
            rangeStart: range.lowerBound,
            rangeEnd: range.upperBound,
            color: color
        )
        add(new)
        return new
    }

    func highlights(in blockIndex: Int, textIndex: Int) -> [Highlight] {
        highlights.filter { $0.blockIndex == blockIndex && $0.textIndex == textIndex }
    }

    func load(_ items: [Highlight]) {
        highlights = items
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild build -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -configuration Debug`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add GoatMarkdown/HighlightState.swift
git commit -m "feat: add HighlightState for in-memory highlight management"
```

---

### Task 6: HighlightState unit tests (TDD)

**Files:**
- Create: `GoatMarkdownTests/HighlightStateTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import Foundation
import XCTest
@testable import GoatMarkdown

final class HighlightStateTests: XCTestCase {
    private var state: HighlightState!

    override func setUp() {
        super.setUp()
        state = HighlightState()
    }

    override func tearDown() {
        state = nil
        super.tearDown()
    }

    func testAddAppendsHighlight() {
        let h = Highlight(blockIndex: 0, textIndex: 0, rangeStart: 0, rangeEnd: 5, color: .yellow)
        state.add(h)
        XCTAssertEqual(state.highlights, [h])
    }

    func testAddWithSameIDReplaces() {
        let id = UUID()
        let first = Highlight(id: id, blockIndex: 0, textIndex: 0, rangeStart: 0, rangeEnd: 5, color: .yellow)
        let second = Highlight(id: id, blockIndex: 1, textIndex: 0, rangeStart: 0, rangeEnd: 5, color: .blue)
        state.add(first)
        state.add(second)
        XCTAssertEqual(state.highlights.count, 1)
        XCTAssertEqual(state.highlights.first, second)
    }

    func testRemoveDeletesByID() {
        let h = Highlight(blockIndex: 0, textIndex: 0, rangeStart: 0, rangeEnd: 5, color: .yellow)
        state.add(h)
        state.remove(id: h.id)
        XCTAssertTrue(state.highlights.isEmpty)
    }

    func testFindReturnsOverlappingHighlight() {
        let h = Highlight(blockIndex: 0, textIndex: 0, rangeStart: 5, rangeEnd: 15, color: .yellow)
        state.add(h)
        let found = state.find(blockIndex: 0, textIndex: 0, range: 10..<12)
        XCTAssertEqual(found?.id, h.id)
    }

    func testFindReturnsNilForNonOverlapping() {
        state.add(Highlight(blockIndex: 0, textIndex: 0, rangeStart: 5, rangeEnd: 15, color: .yellow))
        XCTAssertNil(state.find(blockIndex: 0, textIndex: 0, range: 20..<25))
    }

    func testFindDistinguishesByTextIndex() {
        let h = Highlight(blockIndex: 0, textIndex: 0, rangeStart: 0, rangeEnd: 10, color: .yellow)
        state.add(h)
        XCTAssertNil(state.find(blockIndex: 0, textIndex: 1, range: 0..<5))
    }

    func testToggleAddsWhenNoExisting() {
        let result = state.toggle(blockIndex: 0, textIndex: 0, range: 0..<5)
        XCTAssertNotNil(result)
        XCTAssertEqual(state.highlights.count, 1)
    }

    func testToggleRemovesWhenExisting() {
        _ = state.toggle(blockIndex: 0, textIndex: 0, range: 0..<5)
        let result = state.toggle(blockIndex: 0, textIndex: 0, range: 0..<5)
        XCTAssertNil(result)
        XCTAssertTrue(state.highlights.isEmpty)
    }

    func testHighlightsInBlockFiltersByBothIndices() {
        state.add(Highlight(blockIndex: 0, textIndex: 0, rangeStart: 0, rangeEnd: 5, color: .yellow))
        state.add(Highlight(blockIndex: 0, textIndex: 1, rangeStart: 0, rangeEnd: 5, color: .green))
        XCTAssertEqual(state.highlights(in: 0, textIndex: 0).count, 1)
        XCTAssertEqual(state.highlights(in: 0, textIndex: 1).count, 1)
        XCTAssertEqual(state.highlights(in: 0, textIndex: 2).count, 0)
    }

    func testLoadReplacesAll() {
        state.add(Highlight(blockIndex: 0, textIndex: 0, rangeStart: 0, rangeEnd: 5, color: .yellow))
        let replacement = [Highlight(blockIndex: 1, textIndex: 0, rangeStart: 0, rangeEnd: 5, color: .blue)]
        state.load(replacement)
        XCTAssertEqual(state.highlights, replacement)
    }
}
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `xcodebuild test -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -only-testing:GoatMarkdownTests/HighlightStateTests`
Expected: 10 tests passed

- [ ] **Step 3: Commit**

```bash
git add GoatMarkdownTests/HighlightStateTests.swift
git commit -m "test: add HighlightState unit tests"
```

---

### Task 6b: HighlightRenderingLogic unit tests (TDD)

**Files:**
- Create: `GoatMarkdownTests/HighlightRenderingLogicTests.swift`

This validates the offset-mapping convention: `applyHighlights` and the keyboard handler must both operate on **rendered** plain text (post-markdown), not raw block text.

- [ ] **Step 1: Write failing tests**

```swift
import Foundation
import SwiftUI
import XCTest
@testable import GoatMarkdown

@MainActor
final class HighlightRenderingLogicTests: XCTestCase {
    func testRenderedPlainTextStripsMarkdownSyntax() {
        let text = "**bold** text"
        let rendered = renderedPlainText(text)
        XCTAssertEqual(rendered, "bold text")
    }

    func testApplyHighlightsUsesRenderedOffsetsForInlineMarkdown() {
        // Paragraph "**bold** text" renders to "bold text" (9 chars).
        // A highlight on "bold" should be at rendered offsets 0..<4, not raw offsets 2..<6.
        let document = MarkdownDocument(blocks: [.paragraph(text: "**bold** text")], rawText: "")
        let state = HighlightState()
        let highlight = Highlight(
            blockIndex: 0,
            textIndex: 0,
            rangeStart: 0,
            rangeEnd: 4,
            color: .yellow
        )
        state.add(highlight)

        let renderer = MarkdownRenderer(document: document, highlightState: state)
        let attributed = renderer.renderAttributedStringForTesting(text: "**bold** text", blockIndex: 0, textIndex: 0)
        let background = backgroundColorRange(in: attributed)
        XCTAssertEqual(background?.lowerBound, 0)
        XCTAssertEqual(background?.upperBound, 4)
    }

    func testApplyHighlightsIgnoresOutOfRangeOffsets() {
        // If somehow a stale highlight has rangeEnd > rendered length, it should be skipped
        // (not crash, not apply to wrong text).
        let document = MarkdownDocument(blocks: [.paragraph(text: "short")], rawText: "")
        let state = HighlightState()
        state.add(Highlight(blockIndex: 0, textIndex: 0, rangeStart: 0, rangeEnd: 100, color: .yellow))

        let renderer = MarkdownRenderer(document: document, highlightState: state)
        let attributed = renderer.renderAttributedStringForTesting(text: "short", blockIndex: 0, textIndex: 0)
        // The whole string should NOT be highlighted (would be the bug)
        let count = attributed.runs.filter { $0.backgroundColor != nil }.count
        XCTAssertEqual(count, 0)
    }

    func testApplyHighlightsRespectsTextIndexScope() {
        // List with two items, each its own textIndex. A highlight on item 0 must not
        // affect item 1.
        let document = MarkdownDocument(
            blocks: [.unorderedList(items: ["alpha", "beta"])],
            rawText: ""
        )
        let state = HighlightState()
        state.add(Highlight(blockIndex: 0, textIndex: 0, rangeStart: 0, rangeEnd: 5, color: .yellow))

        let renderer = MarkdownRenderer(document: document, highlightState: state)
        let alphaAttributed = renderer.renderAttributedStringForTesting(text: "alpha", blockIndex: 0, textIndex: 0)
        let betaAttributed = renderer.renderAttributedStringForTesting(text: "beta", blockIndex: 0, textIndex: 1)

        XCTAssertNotNil(backgroundColorRange(in: alphaAttributed))
        XCTAssertNil(backgroundColorRange(in: betaAttributed))
    }

    // MARK: - Helpers

    private func renderedPlainText(_ text: String) -> String {
        let attributed = (try? AttributedString(markdown: text)) ?? AttributedString(text)
        return String(attributed.characters)
    }

    private func backgroundColorRange(in attributed: AttributedString) -> Range<Int>? {
        let plain = String(attributed.characters) as NSString
        let fullRange = NSRange(location: 0, length: plain.length)
        guard let range = Range(fullRange, in: attributed) else { return nil }
        // Find contiguous run with non-nil backgroundColor
        var lower: Int? = nil
        var upper: Int? = nil
        for run in attributed[range].runs {
            guard run.backgroundColor != nil else { continue }
            let start = attributed.characters.distance(from: attributed.characters.startIndex, to: run.range.lowerBound)
            let end = attributed.characters.distance(from: attributed.characters.startIndex, to: run.range.upperBound)
            if lower == nil { lower = start }
            upper = end
        }
        guard let l = lower, let u = upper else { return nil }
        return l..<u
    }
}
```

- [ ] **Step 2: Add a test-only helper to MarkdownRenderer**

In `GoatMarkdown/MarkdownRenderer.swift`, add this internal method (placed near the other test helpers or in an `internal` extension):

```swift
    func renderAttributedStringForTesting(text: String, blockIndex: Int, textIndex: Int) -> AttributedString {
        return cachedText(text, inBlock: blockIndex, textIndex: textIndex, parseMarkdown: true)
    }
```

Note: This exposes the cache, but it's `internal` so only test target can access.

- [ ] **Step 3: Run tests to verify they pass**

Run: `xcodebuild test -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -only-testing:GoatMarkdownTests/HighlightRenderingLogicTests`
Expected: 4 tests passed

- [ ] **Step 4: Commit**

```bash
git add GoatMarkdownTests/HighlightRenderingLogicTests.swift GoatMarkdown/MarkdownRenderer.swift
git commit -m "test: add HighlightRenderingLogic tests for offset mapping"
```

---

### Task 7: Integrate HighlightState into MarkdownReaderState

**Files:**
- Modify: `GoatMarkdown/MarkdownReaderState.swift:42-46` (init), `:72-87` (selectFile), add property

- [ ] **Step 1: Add highlightStore property and init parameter**

In `GoatMarkdown/MarkdownReaderState.swift`, modify:

Line 28 — add property after `let bookmarkStore: BookmarkStore`:
```swift
    let bookmarkStore: BookmarkStore
    let highlightStore: HighlightStore
```

Line 42-46 — modify init signature and body:
```swift
    init(defaults: UserDefaults = .standard, bookmarkStore: BookmarkStore = BookmarkStore(), highlightStore: HighlightStore = HighlightStore()) {
        self.defaults = defaults
        self.bookmarkStore = bookmarkStore
        self.highlightStore = highlightStore
        self.bodyFontScale = defaults.object(forKey: Self.bodyFontScaleKey) as? Double ?? 1.0
    }
```

- [ ] **Step 2: Add highlightState @Observable property**

After line 27 (`var openMode: OpenMode = .empty`), add:
```swift
    var highlightState = HighlightState()
```

- [ ] **Step 3: Load highlights in selectFile**

In `selectFile(_ url: URL)` method (line 72-87), add at the end before `defer`:
```swift
        let stored = highlightStore.highlights(for: url.path)
        highlightState.load(stored)
```

Full method should look like:
```swift
    func selectFile(_ url: URL) {
        selectedFileURL = url
        isLoading = true
        defer { isLoading = false }

        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            let document = MarkdownParser.parse(text)
            currentDocument = document
            defaults.set(url.path, forKey: Self.lastFileKey)
            pendingScrollBlockIndex = resolvedDefaultBookmarkIndex(in: document, filePath: url.path)
            let stored = highlightStore.highlights(for: url.path)
            highlightState.load(stored)
        } catch {
            currentDocument = MarkdownDocument(blocks: [.paragraph(text: "Unable to read file: \(error.localizedDescription)")], rawText: "")
            pendingScrollBlockIndex = nil
            highlightState.load([])
        }
    }
```

- [ ] **Step 4: Add save method**

After `toggleDefaultBookmark(for:)` method (~line 191), add:
```swift
    func saveHighlights() {
        guard let filePath = selectedFileURL?.path else { return }
        highlightStore.setHighlights(highlightState.highlights, for: filePath)
    }
```

- [ ] **Step 5: Build to verify compilation**

Run: `xcodebuild build -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -configuration Debug`
Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add GoatMarkdown/MarkdownReaderState.swift
git commit -m "feat: integrate HighlightState into MarkdownReaderState"
```

---

### Task 8: Wire highlight persistence on state changes

**Files:**
- Modify: `GoatMarkdown/MarkdownReaderState.swift` — add helper to persist after state changes

- [ ] **Step 1: Add highlighter toggle method**

After the `saveHighlights()` method added in Task 7, add:
```swift
    func toggleHighlight(blockIndex: Int, textIndex: Int, range: Range<Int>) {
        _ = highlightState.toggle(blockIndex: blockIndex, textIndex: textIndex, range: range)
        saveHighlights()
    }
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild build -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -configuration Debug`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add GoatMarkdown/MarkdownReaderState.swift
git commit -m "feat: add toggleHighlight method to MarkdownReaderState"
```

---

## Chunk 4: State Integration (Tasks 7-8b)

### Task 9: Add highlightState parameter to MarkdownRenderer

**Files:**
- Modify: `GoatMarkdown/MarkdownRenderer.swift:3-15` (struct definition)

- [ ] **Step 1: Add highlightState property to MarkdownRenderer**

In `MarkdownRenderer` struct, after `var searchState: SearchState?` (line 6), add:
```swift
    var highlightState: HighlightState?
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild build -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -configuration Debug`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add GoatMarkdown/MarkdownRenderer.swift
git commit -m "feat: add highlightState parameter to MarkdownRenderer"
```

---

### Task 10: Apply highlight backgrounds in cachedText

**Files:**
- Modify: `GoatMarkdown/MarkdownRenderer.swift:100-119` (cachedText), `:121-142` (highlightWords)

- [ ] **Step 1: Add highlightColors function**

After `highlightWords` method (line 142), add:
```swift
    private func applyHighlights(
        in attributed: inout AttributedString,
        blockIndex: Int?,
        textIndex: Int
    ) {
        guard let blockIndex, let highlightState else { return }
        let highlights = highlightState.highlights(in: blockIndex, textIndex: textIndex)
        guard !highlights.isEmpty else { return }

        let plain = String(attributed.characters)
        guard !plain.isEmpty else { return }

        let nsString = plain as NSString
        for highlight in highlights {
            guard highlight.rangeStart >= 0,
                  highlight.rangeEnd <= nsString.length,
                  highlight.rangeStart < highlight.rangeEnd else { continue }

            let nsRange = NSRange(location: highlight.rangeStart, length: highlight.rangeEnd - highlight.rangeStart)
            guard let attrRange = Range(nsRange, in: attributed) else { continue }

            attributed[attrRange].backgroundColor = highlight.color.swiftUIColor
        }
    }
```

- [ ] **Step 2: Call applyHighlights in cachedText**

In `cachedText` method (line 100-119), modify the result processing block. Find:
```swift
        if let query = searchState?.query, !query.isEmpty {
            highlightWords(in: &result, query: query, blockIndex: blockIndex, textIndex: textIndex)
        }
```

Add after it (before the cache store):
```swift
        if let blockIndex {
            applyHighlights(in: &result, blockIndex: blockIndex, textIndex: textIndex)
        }
```

- [ ] **Step 3: Update cache key to include highlight state**

In `cachedText` method, modify the `cacheKey` construction. Replace:
```swift
        if let query = searchState?.query, !query.isEmpty {
            let currentMatchSignature = searchState?.currentMatch?.signature ?? "none"
            cacheKey = "\(parseMarkdown ? "markdown" : "plain")|\(query)|\(blockIndex.map(String.init) ?? "none")|\(textIndex)|\(currentMatchSignature)\n\(text)"
        } else {
            cacheKey = "\(parseMarkdown ? "markdown" : "plain")\n\(text)"
        }
```

With:
```swift
        let highlightFingerprint = highlightState
            .map { $0.highlights(in: blockIndex ?? -1, textIndex: textIndex) }
            .map { $0.map { "\($0.id.uuidString)|\($0.rangeStart)|\($0.rangeEnd)|\($0.color.rawValue)" }.joined(separator: ",") }
            ?? ""
        if let query = searchState?.query, !query.isEmpty {
            let currentMatchSignature = searchState?.currentMatch?.signature ?? "none"
            cacheKey = "\(parseMarkdown ? "markdown" : "plain")|\(query)|\(blockIndex.map(String.init) ?? "none")|\(textIndex)|\(currentMatchSignature)|\(highlightFingerprint)\n\(text)"
        } else {
            cacheKey = "\(parseMarkdown ? "markdown" : "plain")|\(blockIndex.map(String.init) ?? "none")|\(highlightFingerprint)\n\(text)"
        }
```

- [ ] **Step 4: Build to verify compilation**

Run: `xcodebuild build -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -configuration Debug`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add GoatMarkdown/MarkdownRenderer.swift
git commit -m "feat: apply highlight background colors in MarkdownRenderer"
```

---

## Chunk 5: Rendering (Tasks 9-10)

### Task 9: Add highlightState parameter to MarkdownRenderer

**Files:**
- Modify: `GoatMarkdown/MarkdownRenderer.swift:3-15` (struct definition)

- [ ] **Step 1: Add highlightState property to MarkdownRenderer**

In `MarkdownRenderer` struct, after `var searchState: SearchState?` (line 6), add:
```swift
    var highlightState: HighlightState?
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild build -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -configuration Debug`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add GoatMarkdown/MarkdownRenderer.swift
git commit -m "feat: add highlightState parameter to MarkdownRenderer"
```

---

### Task 10: Apply highlight backgrounds in cachedText

**Files:**
- Modify: `GoatMarkdown/MarkdownRenderer.swift:100-119` (cachedText), `:121-142` (highlightWords)

- [ ] **Step 1: Add applyHighlights function**

After `highlightWords` method (line 142), add:
```swift
    private func applyHighlights(
        in attributed: inout AttributedString,
        blockIndex: Int?,
        textIndex: Int
    ) {
        guard let blockIndex, let highlightState else { return }
        let highlights = highlightState.highlights(in: blockIndex, textIndex: textIndex)
        guard !highlights.isEmpty else { return }

        let plain = String(attributed.characters)
        guard !plain.isEmpty else { return }

        let nsString = plain as NSString
        for highlight in highlights {
            guard highlight.rangeStart >= 0,
                  highlight.rangeEnd <= nsString.length,
                  highlight.rangeStart < highlight.rangeEnd else { continue }

            let nsRange = NSRange(location: highlight.rangeStart, length: highlight.rangeEnd - highlight.rangeStart)
            guard let attrRange = Range(nsRange, in: attributed) else { continue }

            attributed[attrRange].backgroundColor = highlight.color.swiftUIColor
        }
    }
```

- [ ] **Step 2: Call applyHighlights in cachedText**

In `cachedText` method (line 100-119), modify the result processing block. Find:
```swift
        if let query = searchState?.query, !query.isEmpty {
            highlightWords(in: &result, query: query, blockIndex: blockIndex, textIndex: textIndex)
        }
```

Add after it (before the cache store):
```swift
        if let blockIndex {
            applyHighlights(in: &result, blockIndex: blockIndex, textIndex: textIndex)
        }
```

- [ ] **Step 3: Update cache key to include highlight state**

In `cachedText` method, modify the `cacheKey` construction. Replace:
```swift
        if let query = searchState?.query, !query.isEmpty {
            let currentMatchSignature = searchState?.currentMatch?.signature ?? "none"
            cacheKey = "\(parseMarkdown ? "markdown" : "plain")|\(query)|\(blockIndex.map(String.init) ?? "none")|\(textIndex)|\(currentMatchSignature)\n\(text)"
        } else {
            cacheKey = "\(parseMarkdown ? "markdown" : "plain")\n\(text)"
        }
```

With:
```swift
        let highlightFingerprint = highlightState
            .map { $0.highlights(in: blockIndex ?? -1, textIndex: textIndex) }
            .map { $0.map { "\($0.id.uuidString)|\($0.rangeStart)|\($0.rangeEnd)|\($0.color.rawValue)" }.joined(separator: ",") }
            ?? ""
        if let query = searchState?.query, !query.isEmpty {
            let currentMatchSignature = searchState?.currentMatch?.signature ?? "none"
            cacheKey = "\(parseMarkdown ? "markdown" : "plain")|\(query)|\(blockIndex.map(String.init) ?? "none")|\(textIndex)|\(currentMatchSignature)|\(highlightFingerprint)\n\(text)"
        } else {
            cacheKey = "\(parseMarkdown ? "markdown" : "plain")|\(blockIndex.map(String.init) ?? "none")|\(highlightFingerprint)\n\(text)"
        }
```

- [ ] **Step 4: Build to verify compilation**

Run: `xcodebuild build -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -configuration Debug`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add GoatMarkdown/MarkdownRenderer.swift
git commit -m "feat: apply highlight background colors in MarkdownRenderer"
```

---

## Chunk 6: Keyboard Shortcut (Tasks 11-12)

### Task 11: Wire Cmd+Shift+H shortcut in ContentView

**Files:**
- Modify: `GoatMarkdown/ContentView.swift:51-62` (MarkdownRenderer init), add state for selection

- [ ] **Step 1: Add selection state to ContentView**

After `@State private var searchScrollTrigger = 0` (line 12), add:
```swift
    @State private var currentTextSelection: TextSelection?
```

- [ ] **Step 2: Pass highlightState to MarkdownRenderer**

In `ContentView`'s `content(for:)` method (line 51-62), modify the `MarkdownRenderer` call:

Find:
```swift
                MarkdownRenderer(
                    document: document,
                    theme: MarkdownTheme(bodyFontScale: state.bodyFontScale),
                    searchState: search,
                    searchScrollTrigger: searchScrollTrigger,
                    pendingScrollBlockIndex: $state.pendingScrollBlockIndex,
                    onToggleBookmark: { state.toggleBookmark(for: $0) },
                    onToggleDefaultBookmark: { state.toggleDefaultBookmark(for: $0) },
                    hasBookmark: { state.hasBookmark(for: $0) },
                    isDefaultBookmark: { state.isDefaultBookmark(for: $0) }
                )
```

Replace with:
```swift
                MarkdownRenderer(
                    document: document,
                    theme: MarkdownTheme(bodyFontScale: state.bodyFontScale),
                    searchState: search,
                    searchScrollTrigger: searchScrollTrigger,
                    pendingScrollBlockIndex: $state.pendingScrollBlockIndex,
                    onToggleBookmark: { state.toggleBookmark(for: $0) },
                    onToggleDefaultBookmark: { state.toggleDefaultBookmark(for: $0) },
                    hasBookmark: { state.hasBookmark(for: $0) },
                    isDefaultBookmark: { state.isDefaultBookmark(for: $0) },
                    highlightState: state.highlightState
                )
```

- [ ] **Step 3: Add Cmd+Shift+H handler with focus guard**

After `.onKeyPress(.init("/"))` block (line 118-122), add:
```swift
        .onKeyPress("h", modifiers: [.command, .shift]) {
            guard state.currentDocument != nil else { return .ignored }
            // Only handle when markdown text is the first responder (not search field, sidebar, etc.)
            guard NSApp.keyWindow?.firstResponder is NSTextView else { return .ignored }
            applyHighlightFromSelection(in: state)
            return .handled
        }
```

- [ ] **Step 4: Add applyHighlightFromSelection helper (using rendered text)**

After `openInNewWindowPanel()` method (line 234-244), add:

```swift
    private func applyHighlightFromSelection(in state: MarkdownReaderState) {
        // MVP: read NSTextView selection and map it to (blockIndex, textIndex, range) using rendered plain text.
        // This is critical: offsets must be in RENDERED text (after AttributedString(markdown:) strips formatting),
        // not raw block text (which includes **, *, [, etc.). SearchState already uses this convention via
        // extractSearchableTexts + renderedPlainText.
        guard let textView = NSApp.keyWindow?.firstResponder as? NSTextView else { return }
        guard let firstRange = textView.selectedRanges.first?.rangeValue,
              firstRange.location != NSNotFound,
              firstRange.length > 0 else { return }

        guard let document = state.currentDocument else { return }

        // Walk through the same per-segment text representation the renderer uses for search.
        // Each (blockIndex, textIndex) segment is one Text view in the renderer.
        var characterOffset = 0
        for (blockIndex, block) in document.blocks.enumerated() {
            let segmentTexts = extractSearchableTexts(from: block)
            for (textIndex, rawText) in segmentTexts.enumerated() {
                // Use rendered plain text (markdown syntax stripped) so offsets match what the
                // user sees in the NSTextView and what applyHighlights() expects.
                let renderedText = renderedPlainText(rawText)
                let segmentLength = (renderedText as NSString).length
                let segmentStart = characterOffset
                let segmentEnd = characterOffset + segmentLength

                if firstRange.location < segmentEnd && firstRange.location + firstRange.length > segmentStart {
                    let localStart = max(0, firstRange.location - segmentStart)
                    let localEnd = min(segmentLength, firstRange.location + firstRange.length - segmentStart)
                    if localStart < localEnd {
                        state.toggleHighlight(blockIndex: blockIndex, textIndex: textIndex, range: localStart..<localEnd)
                    }
                    return
                }
                characterOffset = segmentEnd
            }
        }
    }

    // Mirrors SearchState's extraction + rendering. Duplicated intentionally to keep ContentView
    // independent of SearchState internals; if a third caller appears, extract to a shared utility.
    private func extractSearchableTexts(from block: MarkdownBlock) -> [String] {
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

    private func renderedPlainText(_ text: String) -> String {
        let attributed = (try? AttributedString(markdown: text)) ?? AttributedString(text)
        return String(attributed.characters)
    }
```

- [ ] **Step 5: Add import AppKit if missing**

Check top of `ContentView.swift`. If `import AppKit` is missing, add it.

- [ ] **Step 6: Build to verify compilation**

Run: `xcodebuild build -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -configuration Debug`
Expected: BUILD SUCCEEDED

- [ ] **Step 7: Commit**

```bash
git add GoatMarkdown/ContentView.swift
git commit -m "feat: add Cmd+Shift+H shortcut for highlighting selection"
```

---

### Task 12: Update README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add highlighter feature to Features list**

In `README.md`, after the "书签" line (line 12), add:
```markdown
- 荧光笔：选中文字后按 `Cmd + Shift + H` 添加黄色高亮，再次按相同快捷键移除
```

- [ ] **Step 2: Add Cmd+Shift+H to keyboard shortcuts table**

In the keyboard shortcuts table, after the `Cmd + F` row, add:
```markdown
| `Cmd + Shift + H` | 高亮 / 取消高亮当前选中文本 |
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: document highlighter feature and Cmd+Shift+H shortcut"
```

---

## Chunk 7: Manual Testing & Polish (Task 13)

### Task 13: Manual test pass

- [ ] **Step 1: Build the app**

Run: `xcodebuild build -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -configuration Debug`
Expected: BUILD SUCCEEDED

- [ ] **Step 2: Run all tests**

Run: `xcodebuild test -project GoatMarkdown.xcodeproj -scheme GoatMarkdown`
Expected: All tests pass (existing + new HighlightStoreTests + HighlightStateTests)

- [ ] **Step 3: Manual verification checklist**

Open the app and verify:
- [ ] Open a .md file with paragraphs
- [ ] Select text in a paragraph
- [ ] Press `Cmd+Shift+H` → text gets yellow background
- [ ] Press `Cmd+Shift+H` again on same selection → highlight removed
- [ ] Highlight different text → multiple highlights visible
- [ ] Close and reopen file → highlights persist
- [ ] Search with `Cmd+F` → search match background shows on top of highlight
- [ ] Run all existing tests → no regressions

If any step fails, fix and re-verify before final commit.

- [ ] **Step 4: Final commit if any fixes needed**

```bash
git add -u
git commit -m "fix: address manual testing issues"
```

---

## Notes

- **Selection detection (MVP)**: We use `NSApp.keyWindow?.firstResponder as? NSTextView` to get current selection. This works because SwiftUI `Text` with `.textSelection(.enabled)` is backed by an NSTextView under the hood.
- **Block offset calculation**: We concatenate all block texts sequentially and match selection range against this concatenated string. This is a simple MVP approach — if selection spans multiple blocks, we apply highlight to the first overlapping block only.
- **Single-block limitation**: The `applyHighlightFromSelection` helper processes one block per Cmd+H press. Multi-block highlighting is out of scope for MVP.
- **No tests for ContentView keyboard handler**: This is hard to unit test without UI test infrastructure. Manual verification is the primary validation.
