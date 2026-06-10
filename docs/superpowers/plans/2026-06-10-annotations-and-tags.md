# Annotations and Tags Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add optional text notes to highlights and user-defined tags to bookmarks, with filtering support.

**Architecture:** Extend existing `Highlight` and `Bookmark` models with optional fields. Add context menu on highlighted text for note editing (popover). Add tag management to bookmark sidebar with color-coded pills and dropdown filter. All persistence uses existing UserDefaults-based stores (Codable handles new optional fields automatically).

**Tech Stack:** Swift, SwiftUI, macOS 15+, XcodeGen, XCTest

---

## Chunk 1: Highlight Notes

### Task 1: Add `note` field to Highlight model

**Files:**
- Modify: `GoatMarkdown/Highlight.swift`
- Test: `GoatMarkdownTests/HighlightNoteTests.swift`

- [ ] **Step 1: Write failing test for Highlight with note**

```swift
// GoatMarkdownTests/HighlightNoteTests.swift
import Foundation
import XCTest
@testable import GoatMarkdown

final class HighlightNoteTests: XCTestCase {
    func testHighlightDefaultsToNilNote() {
        let h = Highlight(blockIndex: 0, textIndex: 0, rangeStart: 0, rangeEnd: 5, color: .yellow)
        XCTAssertNil(h.note)
    }

    func testHighlightStoresNote() {
        let h = Highlight(blockIndex: 0, textIndex: 0, rangeStart: 0, rangeEnd: 5, color: .yellow, note: "test note")
        XCTAssertEqual(h.note, "test note")
    }

    func testHighlightNoteRoundTripsCodable() throws {
        let original = Highlight(blockIndex: 1, textIndex: 0, rangeStart: 3, rangeEnd: 8, color: .green, note: "important")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Highlight.self, from: data)
        XCTAssertEqual(decoded.note, "important")
    }

    func testHighlightWithoutNoteDecodesFromLegacyData() throws {
        // Simulates data from before the note field existed
        let legacy = Highlight(blockIndex: 0, textIndex: 0, rangeStart: 0, rangeEnd: 5, color: .yellow)
        let data = try JSONEncoder().encode(legacy)
        // Remove the note key to simulate truly legacy data
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        json.removeValue(forKey: "note")
        let legacyData = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(Highlight.self, from: legacyData)
        XCTAssertNil(decoded.note)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -destination "platform=macOS" -only-testing:GoatMarkdownTests/HighlightNoteTests 2>&1 | grep -E "(Test Case|PASS|FAIL|error:)"`
Expected: Compilation error — `note` parameter doesn't exist on `Highlight`

- [ ] **Step 3: Implement — add `note` field to Highlight**

```swift
// GoatMarkdown/Highlight.swift
import Foundation

struct Highlight: Equatable, Codable, Identifiable {
    let id: UUID
    let blockIndex: Int
    let textIndex: Int
    let rangeStart: Int
    let rangeEnd: Int
    let color: HighlightColor
    let createdAt: Date
    var note: String?

    init(
        id: UUID = UUID(),
        blockIndex: Int,
        textIndex: Int,
        rangeStart: Int,
        rangeEnd: Int,
        color: HighlightColor,
        createdAt: Date = Date(),
        note: String? = nil
    ) {
        self.id = id
        self.blockIndex = blockIndex
        self.textIndex = textIndex
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
        self.color = color
        self.createdAt = createdAt
        self.note = note
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -destination "platform=macOS" -only-testing:GoatMarkdownTests/HighlightNoteTests 2>&1 | grep -E "(Test Case|PASS|FAIL|error:)"`
Expected: All 4 tests PASS

- [ ] **Step 5: Run full test suite to verify no regressions**

Run: `xcodebuild test -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -destination "platform=macOS" 2>&1 | tail -5`
Expected: TEST SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add GoatMarkdown/Highlight.swift GoatMarkdownTests/HighlightNoteTests.swift
git commit -m "feat: add note field to Highlight model"
```

---

### Task 2: Add `updateNote` method to HighlightState

**Files:**
- Modify: `GoatMarkdown/HighlightState.swift`
- Test: `GoatMarkdownTests/HighlightNoteTests.swift` (append)

- [ ] **Step 1: Write failing test**

Append to `GoatMarkdownTests/HighlightNoteTests.swift`:

```swift
final class HighlightStateNoteTests: XCTestCase {
    private var state: HighlightState!

    override func setUp() {
        super.setUp()
        state = HighlightState()
    }

    override func tearDown() {
        state = nil
        super.tearDown()
    }

    func testUpdateNoteOnExistingHighlight() {
        let h = Highlight(blockIndex: 0, textIndex: 0, rangeStart: 0, rangeEnd: 5, color: .yellow)
        state.add(h)
        state.updateNote(id: h.id, note: "my annotation")
        XCTAssertEqual(state.highlights.first?.note, "my annotation")
    }

    func testUpdateNoteToNilClearsNote() {
        let h = Highlight(blockIndex: 0, textIndex: 0, rangeStart: 0, rangeEnd: 5, color: .yellow, note: "old")
        state.add(h)
        state.updateNote(id: h.id, note: nil)
        XCTAssertNil(state.highlights.first?.note)
    }

    func testUpdateNoteOnNonexistentIDDoesNothing() {
        let h = Highlight(blockIndex: 0, textIndex: 0, rangeStart: 0, rangeEnd: 5, color: .yellow)
        state.add(h)
        state.updateNote(id: UUID(), note: "ghost")
        XCTAssertNil(state.highlights.first?.note)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -destination "platform=macOS" -only-testing:GoatMarkdownTests/HighlightStateNoteTests 2>&1 | grep -E "(Test Case|PASS|FAIL|error:)"`
Expected: Compilation error — `updateNote` method doesn't exist

- [ ] **Step 3: Implement updateNote in HighlightState**

Add to `GoatMarkdown/HighlightState.swift`:

```swift
func updateNote(id: UUID, note: String?) {
    guard let index = highlights.firstIndex(where: { $0.id == id }) else { return }
    highlights[index].note = note
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -destination "platform=macOS" -only-testing:GoatMarkdownTests/HighlightStateNoteTests 2>&1 | grep -E "(Test Case|PASS|FAIL|error:)"`
Expected: All 3 tests PASS

- [ ] **Step 5: Run full test suite**

Run: `xcodebuild test -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -destination "platform=macOS" 2>&1 | tail -5`
Expected: TEST SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add GoatMarkdown/HighlightState.swift GoatMarkdownTests/HighlightNoteTests.swift
git commit -m "feat: add updateNote method to HighlightState"
```

---

### Task 3: Wire updateHighlightNote through MarkdownReaderState

**Files:**
- Modify: `GoatMarkdown/MarkdownReaderState.swift`
- Test: `GoatMarkdownTests/HighlightNoteTests.swift` (append)

- [ ] **Step 1: Write failing integration test**

Append to `GoatMarkdownTests/HighlightNoteTests.swift`:

```swift
final class MarkdownReaderStateNoteTests: XCTestCase {
    func testUpdateHighlightNotePersists() {
        let suiteName = "NoteIntegration-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let highlightStore = HighlightStore(defaults: defaults)
        let state = MarkdownReaderState(defaults: defaults, highlightStore: highlightStore)
        state.highlightState.add(Highlight(blockIndex: 0, textIndex: 0, rangeStart: 0, rangeEnd: 5, color: .yellow))

        let id = state.highlightState.highlights.first!.id
        state.updateHighlightNote(id: id, note: "persisted note")

        // Note should be in state
        XCTAssertEqual(state.highlightState.highlights.first?.note, "persisted note")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Expected: Compilation error — `updateHighlightNote` doesn't exist

- [ ] **Step 3: Implement updateHighlightNote**

Add to `GoatMarkdown/MarkdownReaderState.swift`, after the `toggleHighlight` method:

```swift
func updateHighlightNote(id: UUID, note: String?) {
    highlightState.updateNote(id: id, note: note)
    saveHighlights()
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -destination "platform=macOS" -only-testing:GoatMarkdownTests/MarkdownReaderStateNoteTests 2>&1 | grep -E "(Test Case|PASS|FAIL|error:)"`
Expected: PASS

- [ ] **Step 5: Run full test suite**

Run: `xcodebuild test -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -destination "platform=macOS" 2>&1 | tail -5`
Expected: TEST SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add GoatMarkdown/MarkdownReaderState.swift GoatMarkdownTests/HighlightNoteTests.swift
git commit -m "feat: add updateHighlightNote to MarkdownReaderState"
```

---

### Task 4: Create NoteEditorSheet UI

**Files:**
- Create: `GoatMarkdown/NoteEditorSheet.swift`

- [ ] **Step 1: Implement NoteEditorSheet**

```swift
// GoatMarkdown/NoteEditorSheet.swift
import SwiftUI

struct NoteEditorSheet: View {
    let highlightID: UUID
    @Binding var isPresented: Bool
    var initialNote: String
    var onSave: (UUID, String?) -> Void

    @State private var text: String = ""
    private static let maxNoteLength = 500

    init(highlightID: UUID, isPresented: Binding<Bool>, initialNote: String?, onSave: @escaping (UUID, String?) -> Void) {
        self.highlightID = highlightID
        self._isPresented = isPresented
        self.initialNote = initialNote ?? ""
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Note")
                .font(.headline)

            TextEditor(text: $text)
                .font(.body)
                .frame(minHeight: 80, maxHeight: 120)
                .border(Color.secondary.opacity(0.3))
                .onChange(of: text) { _, newValue in
                    if newValue.count > Self.maxNoteLength {
                        text = String(newValue.prefix(Self.maxNoteLength))
                    }
                }

            Text("\(text.count)/\(Self.maxNoteLength)")
                .font(.caption)
                .foregroundStyle(text.count >= Self.maxNoteLength ? .red : .secondary)

            HStack {
                if !initialNote.isEmpty {
                    Button("Delete Note", role: .destructive) {
                        onSave(highlightID, nil)
                        isPresented = false
                    }
                }
                Spacer()
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                Button("Save") {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSave(highlightID, trimmed.isEmpty ? nil : trimmed)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && initialNote.isEmpty)
            }
        }
        .padding()
        .frame(width: 320)
        .onAppear {
            text = initialNote
        }
    }
}
```

- [ ] **Step 2: Run xcodegen and build to verify compilation**

```bash
xcodegen generate
```

Run: `xcodebuild build -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -destination "platform=macOS" 2>&1 | grep -E "(BUILD|error:)"`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add GoatMarkdown/NoteEditorSheet.swift
git commit -m "feat: add NoteEditorSheet for editing highlight notes"
```

---

### Task 5: Add context menu and tooltip to highlighted text in MarkdownRenderer

**Files:**
- Modify: `GoatMarkdown/MarkdownRenderer.swift`
- Modify: `GoatMarkdown/ContentView.swift`

- [ ] **Step 1: Add onHighlightAction callback to MarkdownRenderer**

Add to `MarkdownRenderer` struct properties:

```swift
var onEditHighlightNote: ((Highlight) -> Void)?
var onRemoveHighlight: ((UUID) -> Void)?
```

- [ ] **Step 2: Modify cachedText to attach tooltip for highlights with notes**

In `MarkdownRenderer.swift`, modify the `applyHighlights` method to also add `.toolTip` for highlights with notes. Since SwiftUI `Text` with `AttributedString` doesn't natively support per-range tooltips, use an overlay approach instead.

Create a helper method to detect which highlight is under the cursor. Add after `applyHighlights`:

```swift
private func highlightAtCursor(in blockIndex: Int, textIndex: Int) -> Highlight? {
    guard let highlightState else { return nil }
    return highlightState.highlights(in: blockIndex, textIndex: textIndex).first
}
```

- [ ] **Step 3: Add context menu to paragraph rendering**

Modify the `.paragraph` case in `renderBlock` to add a context menu on highlighted text. Wrap the `Text` view:

```swift
case .paragraph(let text):
    Text(cachedInline(text, inBlock: blockIndex))
        .font(theme.bodyFont)
        .foregroundStyle(theme.bodyColor)
        .id(matchScrollID(for: blockIndex, textIndex: 0))
        .contextMenu {
            if let highlights = highlightState?.highlights(in: blockIndex, textIndex: 0),
               !highlights.isEmpty {
                let highlight = highlights.first!
                if highlight.note != nil {
                    Button("Edit Note") { onEditHighlightNote?(highlight) }
                } else {
                    Button("Add Note") { onEditHighlightNote?(highlight) }
                }
                Button("Remove Highlight", role: .destructive) { onRemoveHighlight?(highlight.id) }
            }
        }
```

Note: This attaches the context menu at block level. If the block has any highlights, the menu shows note options. This is a pragmatic approach since SwiftUI doesn't support per-character context menus on `Text`.

- [ ] **Step 4: Add tooltip with proper format for highlights with notes**

The tooltip should show selected text snippet + note. Use `.help()` with formatted string:

```swift
.help({
    if let highlights = highlightState?.highlights(in: blockIndex, textIndex: 0),
       let annotated = highlights.first(where: { $0.note != nil }),
       let note = annotated.note {
        let snippet = String(text.prefix(40))
        return "\(snippet)...\n\nNote: \(note)"
    }
    return ""
}())
```

Note: SwiftUI's `.help()` does not support custom delay (uses system default ~0.5s). This is acceptable.

- [ ] **Step 5: Add visual indicator (📝) for highlights with notes**

After the `.help()` modifier, add an overlay for blocks containing annotated highlights:

```swift
.overlay(alignment: .topTrailing) {
    if let highlights = highlightState?.highlights(in: blockIndex, textIndex: 0),
       highlights.contains(where: { $0.note != nil }) {
        Text("📝")
            .font(.system(size: 9))
            .padding(2)
    }
}
```

- [ ] **Step 5: Wire callbacks in ContentView**

In `ContentView.swift`, add state and pass callbacks to `MarkdownRenderer`:

```swift
// Add to ContentView state:
@State private var editingHighlight: Highlight?
@State private var showNoteEditor = false
```

Pass to MarkdownRenderer:

```swift
MarkdownRenderer(
    // ...existing params...
    onEditHighlightNote: { highlight in
        editingHighlight = highlight
        showNoteEditor = true
    },
    onRemoveHighlight: { id in
        state.highlightState.remove(id: id)
        state.saveHighlights()
    }
)
.sheet(isPresented: $showNoteEditor) {
    if let highlight = editingHighlight {
        NoteEditorSheet(
            highlightID: highlight.id,
            isPresented: $showNoteEditor,
            initialNote: highlight.note,
            onSave: { id, note in
                state.updateHighlightNote(id: id, note: note)
            }
        )
    }
}
```

- [ ] **Step 6: Build and verify**

Run: `xcodebuild build -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -destination "platform=macOS" 2>&1 | grep -E "(BUILD|error:)"`
Expected: BUILD SUCCEEDED

- [ ] **Step 7: Run full test suite**

Run: `xcodebuild test -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -destination "platform=macOS" 2>&1 | tail -5`
Expected: TEST SUCCEEDED

- [ ] **Step 8: Commit**

```bash
git add GoatMarkdown/MarkdownRenderer.swift GoatMarkdown/ContentView.swift
git commit -m "feat: add context menu and tooltip for highlight notes"
```

---

## Chunk 2: Bookmark Tags

### Task 6: Add `tags` field to Bookmark model

**Files:**
- Modify: `GoatMarkdown/Bookmark.swift`
- Test: `GoatMarkdownTests/BookmarkTagsTests.swift`

- [ ] **Step 1: Write failing test for Bookmark with tags**

```swift
// GoatMarkdownTests/BookmarkTagsTests.swift
import Foundation
import XCTest
@testable import GoatMarkdown

final class BookmarkTagsTests: XCTestCase {
    func testBookmarkDefaultsToEmptyTags() {
        let b = Bookmark(
            id: UUID(), blockIndex: 0, blockSignature: "sig",
            title: "Test", preview: "preview", isDefault: false, createdAt: Date()
        )
        XCTAssertEqual(b.tags, [])
    }

    func testBookmarkStoresTags() {
        let b = Bookmark(
            id: UUID(), blockIndex: 0, blockSignature: "sig",
            title: "Test", preview: "preview", isDefault: false, createdAt: Date(),
            tags: ["important", "todo"]
        )
        XCTAssertEqual(b.tags, ["important", "todo"])
    }

    func testBookmarkTagsRoundTripCodable() throws {
        let original = Bookmark(
            id: UUID(), blockIndex: 1, blockSignature: "sig-1",
            title: "Heading", preview: "text", isDefault: false, createdAt: Date(),
            tags: ["review", "chapter1"]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Bookmark.self, from: data)
        XCTAssertEqual(decoded.tags, ["review", "chapter1"])
    }

    func testBookmarkWithoutTagsDecodesFromLegacyData() throws {
        let legacy = Bookmark(
            id: UUID(), blockIndex: 0, blockSignature: "sig",
            title: "Old", preview: "p", isDefault: false, createdAt: Date()
        )
        let data = try JSONEncoder().encode(legacy)
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        json.removeValue(forKey: "tags")
        let legacyData = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(Bookmark.self, from: legacyData)
        XCTAssertEqual(decoded.tags, [])
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -destination "platform=macOS" -only-testing:GoatMarkdownTests/BookmarkTagsTests 2>&1 | grep -E "(Test Case|PASS|FAIL|error:)"`
Expected: Compilation error — `tags` parameter doesn't exist on `Bookmark`

- [ ] **Step 3: Implement — add `tags` field to Bookmark**

Modify `GoatMarkdown/Bookmark.swift`, update the struct:

```swift
struct Bookmark: Equatable, Codable, Identifiable {
    let id: UUID
    var blockIndex: Int
    var blockSignature: String
    var title: String
    var preview: String
    var isDefault: Bool
    var createdAt: Date
    var tags: [String]

    init(
        id: UUID = UUID(),
        blockIndex: Int,
        blockSignature: String,
        title: String,
        preview: String,
        isDefault: Bool,
        createdAt: Date,
        tags: [String] = []
    ) {
        self.id = id
        self.blockIndex = blockIndex
        self.blockSignature = blockSignature
        self.title = title
        self.preview = preview
        self.isDefault = isDefault
        self.createdAt = createdAt
        self.tags = tags
    }

    // Custom decoder to handle legacy data without tags
    private enum CodingKeys: String, CodingKey {
        case id, blockIndex, blockSignature, title, preview, isDefault, createdAt, tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        blockIndex = try container.decode(Int.self, forKey: .blockIndex)
        blockSignature = try container.decode(String.self, forKey: .blockSignature)
        title = try container.decode(String.self, forKey: .title)
        preview = try container.decode(String.self, forKey: .preview)
        isDefault = try container.decode(Bool.self, forKey: .isDefault)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
    }
}
```

- [ ] **Step 4: Fix existing BookmarkStore tests (fixture needs update)**

Update the `Bookmark.fixture` extension in `BookmarkStoreTests.swift` if it breaks (it should still compile since `tags` has a default value).

- [ ] **Step 5: Run test to verify it passes**

Run: `xcodebuild test -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -destination "platform=macOS" -only-testing:GoatMarkdownTests/BookmarkTagsTests 2>&1 | grep -E "(Test Case|PASS|FAIL|error:)"`
Expected: All 4 tests PASS

- [ ] **Step 6: Run full test suite**

Run: `xcodebuild test -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -destination "platform=macOS" 2>&1 | tail -5`
Expected: TEST SUCCEEDED

- [ ] **Step 7: Commit**

```bash
git add GoatMarkdown/Bookmark.swift GoatMarkdownTests/BookmarkTagsTests.swift
git commit -m "feat: add tags field to Bookmark model"
```

---

### Task 7: Add tag management methods to BookmarkStore

**Files:**
- Modify: `GoatMarkdown/Bookmark.swift` (BookmarkStore class)
- Test: `GoatMarkdownTests/BookmarkTagsTests.swift` (append)

- [ ] **Step 1: Write failing tests**

Append to `GoatMarkdownTests/BookmarkTagsTests.swift`:

```swift
final class BookmarkStoreTagTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "BookmarkStoreTagTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testUpdateTagsPersists() {
        let store = BookmarkStore(defaults: defaults)
        let bookmark = Bookmark(
            id: UUID(), blockIndex: 0, blockSignature: "sig",
            title: "T", preview: "p", isDefault: false, createdAt: Date()
        )
        store.add(bookmark, for: "/tmp/A.md")
        store.updateTags(bookmark.id, tags: ["important", "review"], for: "/tmp/A.md")

        let stored = store.bookmarks(for: "/tmp/A.md").first
        XCTAssertEqual(stored?.tags, ["important", "review"])
    }

    func testAllTagsReturnsUniqueTags() {
        let store = BookmarkStore(defaults: defaults)
        let b1 = Bookmark(
            id: UUID(), blockIndex: 0, blockSignature: "sig-0",
            title: "A", preview: "", isDefault: false, createdAt: Date(), tags: ["foo", "bar"]
        )
        let b2 = Bookmark(
            id: UUID(), blockIndex: 1, blockSignature: "sig-1",
            title: "B", preview: "", isDefault: false, createdAt: Date(), tags: ["bar", "baz"]
        )
        store.add(b1, for: "/tmp/A.md")
        store.add(b2, for: "/tmp/A.md")

        let allTags = store.allTags(for: "/tmp/A.md")
        XCTAssertEqual(Set(allTags), Set(["foo", "bar", "baz"]))
    }

    func testFilterBookmarksByTag() {
        let store = BookmarkStore(defaults: defaults)
        let b1 = Bookmark(
            id: UUID(), blockIndex: 0, blockSignature: "sig-0",
            title: "A", preview: "", isDefault: false, createdAt: Date(), tags: ["important"]
        )
        let b2 = Bookmark(
            id: UUID(), blockIndex: 1, blockSignature: "sig-1",
            title: "B", preview: "", isDefault: false, createdAt: Date(), tags: ["todo"]
        )
        store.add(b1, for: "/tmp/A.md")
        store.add(b2, for: "/tmp/A.md")

        let filtered = store.bookmarks(for: "/tmp/A.md", withTag: "important")
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.title, "A")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -destination "platform=macOS" -only-testing:GoatMarkdownTests/BookmarkStoreTagTests 2>&1 | grep -E "(Test Case|PASS|FAIL|error:)"`
Expected: Compilation error — methods don't exist

- [ ] **Step 3: Implement tag methods in BookmarkStore**

Add to `BookmarkStore` in `GoatMarkdown/Bookmark.swift`:

```swift
func updateTags(_ id: UUID, tags: [String], for filePath: String) {
    guard var list = byFilePath[filePath] else { return }
    guard let index = list.firstIndex(where: { $0.id == id }) else { return }
    list[index].tags = tags
    byFilePath[filePath] = list
    persist()
}

func allTags(for filePath: String) -> [String] {
    let bookmarks = byFilePath[filePath] ?? []
    let allTags = bookmarks.flatMap(\.tags)
    return Array(Set(allTags)).sorted()
}

func bookmarks(for filePath: String, withTag tag: String) -> [Bookmark] {
    let all = byFilePath[filePath] ?? []
    return all.filter { $0.tags.contains(tag) }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -destination "platform=macOS" -only-testing:GoatMarkdownTests/BookmarkStoreTagTests 2>&1 | grep -E "(Test Case|PASS|FAIL|error:)"`
Expected: All 3 tests PASS

- [ ] **Step 5: Run full test suite**

Run: `xcodebuild test -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -destination "platform=macOS" 2>&1 | tail -5`
Expected: TEST SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add GoatMarkdown/Bookmark.swift GoatMarkdownTests/BookmarkTagsTests.swift
git commit -m "feat: add tag management methods to BookmarkStore"
```

---

### Task 8: Create TagRegistry for stable color assignment

**Files:**
- Create: `GoatMarkdown/TagRegistry.swift`
- Test: `GoatMarkdownTests/TagRegistryTests.swift`

- [ ] **Step 1: Write failing test**

```swift
// GoatMarkdownTests/TagRegistryTests.swift
import Foundation
import XCTest
import SwiftUI
@testable import GoatMarkdown

final class TagRegistryTests: XCTestCase {
    func testColorForTagIsStable() {
        let color1 = TagRegistry.shared.color(for: "important")
        let color2 = TagRegistry.shared.color(for: "important")
        XCTAssertEqual(color1, color2)
    }

    func testDifferentTagsProduceDifferentColors() {
        let c1 = TagRegistry.shared.color(for: "important")
        let c2 = TagRegistry.shared.color(for: "todo")
        // Colors might collide in theory but these two common words should differ
        XCTAssertNotEqual(c1, c2)
    }

    func testEmptyTagReturnsColor() {
        let color = TagRegistry.shared.color(for: "")
        // Should not crash, returns some color
        XCTAssertNotNil(color)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Expected: Compilation error — `TagRegistry` doesn't exist

- [ ] **Step 3: Implement TagRegistry**

```swift
// GoatMarkdown/TagRegistry.swift
import SwiftUI

final class TagRegistry {
    static let shared = TagRegistry()

    private init() {}

    func color(for tag: String) -> Color {
        let hash = stableHash(tag)
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.65, brightness: 0.75)
    }

    private func stableHash(_ string: String) -> UInt {
        // FNV-1a hash for stability across runs
        var hash: UInt = 14695981039346656037
        for byte in string.utf8 {
            hash ^= UInt(byte)
            hash &*= 1099511628211
        }
        return hash
    }
}
```

- [ ] **Step 4: Regenerate Xcode project and run test**

```bash
xcodegen generate
```

Run: `xcodebuild test -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -destination "platform=macOS" -only-testing:GoatMarkdownTests/TagRegistryTests 2>&1 | grep -E "(Test Case|PASS|FAIL|error:)"`
Expected: All 3 tests PASS

- [ ] **Step 5: Commit**

```bash
git add GoatMarkdown/TagRegistry.swift GoatMarkdownTests/TagRegistryTests.swift
git commit -m "feat: add TagRegistry for stable tag color assignment"
```

---

### Task 9: Create TagPillView component

**Files:**
- Create: `GoatMarkdown/TagPillView.swift`

- [ ] **Step 1: Implement TagPillView**

```swift
// GoatMarkdown/TagPillView.swift
import SwiftUI

struct TagPillView: View {
    let tag: String

    var body: some View {
        Text(tag)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(TagRegistry.shared.color(for: tag))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
```

- [ ] **Step 2: Regenerate Xcode project and build to verify compilation**

```bash
xcodegen generate
```

Run: `xcodebuild build -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -destination "platform=macOS" 2>&1 | grep -E "(BUILD|error:)"`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add GoatMarkdown/TagPillView.swift
git commit -m "feat: add TagPillView reusable component"
```

---

### Task 10: Create TagEditorSheet

**Files:**
- Create: `GoatMarkdown/TagEditorSheet.swift`

- [ ] **Step 1: Implement TagEditorSheet**

```swift
// GoatMarkdown/TagEditorSheet.swift
import SwiftUI

struct TagEditorSheet: View {
    let bookmarkID: UUID
    @Binding var isPresented: Bool
    var initialTags: [String]
    var existingTags: [String]
    var onSave: (UUID, [String]) -> Void

    @State private var text: String = ""

    init(bookmarkID: UUID, isPresented: Binding<Bool>, initialTags: [String], existingTags: [String], onSave: @escaping (UUID, [String]) -> Void) {
        self.bookmarkID = bookmarkID
        self._isPresented = isPresented
        self.initialTags = initialTags
        self.existingTags = existingTags
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tags")
                .font(.headline)

            TextField("Enter tags (comma-separated)", text: $text)
                .textFieldStyle(.plain)
                .font(.body)
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            if !suggestedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(suggestedTags, id: \.self) { tag in
                            Button {
                                appendTag(tag)
                            } label: {
                                TagPillView(tag: tag)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if !currentTags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(currentTags, id: \.self) { tag in
                        TagPillView(tag: tag)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                Button("Save") {
                    onSave(bookmarkID, currentTags)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 320)
        .onAppear {
            text = initialTags.joined(separator: ", ")
        }
    }

    private var currentTags: [String] {
        text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var suggestedTags: [String] {
        existingTags.filter { tag in
            !currentTags.contains(tag)
        }
    }

    private func appendTag(_ tag: String) {
        let current = currentTags
        if !current.contains(tag) {
            if text.isEmpty {
                text = tag
            } else {
                text += ", \(tag)"
            }
        }
    }
}
```

- [ ] **Step 2: Regenerate Xcode project and build to verify compilation**

```bash
xcodegen generate
```

Run: `xcodebuild build -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -destination "platform=macOS" 2>&1 | grep -E "(BUILD|error:)"`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add GoatMarkdown/TagEditorSheet.swift
git commit -m "feat: add TagEditorSheet for bookmark tag editing"
```

---

### Task 11: Update BookmarkSidebarSection with tags filter and display

**Files:**
- Modify: `GoatMarkdown/BookmarkSidebarSection.swift`

- [ ] **Step 1: Add tag filter state and dropdown**

Replace `GoatMarkdown/BookmarkSidebarSection.swift` with updated version:

```swift
import SwiftUI

struct BookmarkSidebarSection: View {
    @Bindable var state: MarkdownReaderState
    @State private var selectedTag: String?
    @State private var editingBookmarkForTags: Bookmark?
    @State private var showTagEditor = false

    var body: some View {
        if state.currentDocument != nil, let filePath = state.selectedFileURL?.path {
            let allBookmarks = state.bookmarkStore.bookmarks(for: filePath)
            let allTags = state.bookmarkStore.allTags(for: filePath)
            let filteredBookmarks = filteredBookmarks(allBookmarks)

            Section("Bookmarks") {
                if !allTags.isEmpty {
                    Picker("Filter", selection: $selectedTag) {
                        Text("All Bookmarks").tag(nil as String?)
                        ForEach(allTags, id: \.self) { tag in
                            Label(tag, systemImage: "tag")
                                .tag(tag as String?)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                if filteredBookmarks.isEmpty {
                    Text(selectedTag != nil ? "No bookmarks with this tag" : "No bookmarks for this file")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredBookmarks) { bookmark in
                        BookmarkRow(
                            bookmark: bookmark,
                            onSelect: { state.scrollToBookmark(bookmark) },
                            onToggleDefault: {
                                if bookmark.isDefault {
                                    state.bookmarkStore.setDefault(UUID(), for: filePath)
                                } else {
                                    state.bookmarkStore.setDefault(bookmark.id, for: filePath)
                                }
                            },
                            onDelete: {
                                state.bookmarkStore.remove(bookmark.id, for: filePath)
                            },
                            onEditTags: {
                                editingBookmarkForTags = bookmark
                                showTagEditor = true
                            }
                        )
                    }
                }
            }
            .sheet(isPresented: $showTagEditor) {
                if let bookmark = editingBookmarkForTags {
                    TagEditorSheet(
                        bookmarkID: bookmark.id,
                        isPresented: $showTagEditor,
                        initialTags: bookmark.tags,
                        existingTags: allTags,
                        onSave: { id, tags in
                            state.bookmarkStore.updateTags(id, tags: tags, for: filePath)
                        }
                    )
                }
            }
        }
    }

    private func filteredBookmarks(_ bookmarks: [Bookmark]) -> [Bookmark] {
        guard let tag = selectedTag else { return bookmarks }
        return bookmarks.filter { $0.tags.contains(tag) }
    }
}

private struct BookmarkRow: View {
    let bookmark: Bookmark
    let onSelect: () -> Void
    let onToggleDefault: () -> Void
    let onDelete: () -> Void
    let onEditTags: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onToggleDefault) {
                Image(systemName: bookmark.isDefault ? "star.fill" : "star")
                    .foregroundStyle(bookmark.isDefault ? Color.yellow : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(bookmark.isDefault ? "Unset auto-open default" : "Set as auto-open default")

            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(bookmark.title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    if !bookmark.preview.isEmpty {
                        Text(bookmark.preview)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if !bookmark.tags.isEmpty {
                        HStack(spacing: 3) {
                            ForEach(bookmark.tags, id: \.self) { tag in
                                TagPillView(tag: tag)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .contextMenu {
            Button(bookmark.isDefault ? "Unset default" : "Set as default", action: onToggleDefault)
            Button("Edit Tags", action: onEditTags)
            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild build -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -destination "platform=macOS" 2>&1 | grep -E "(BUILD|error:)"`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Run full test suite**

Run: `xcodebuild test -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -destination "platform=macOS" 2>&1 | tail -5`
Expected: TEST SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add GoatMarkdown/BookmarkSidebarSection.swift
git commit -m "feat: add tag filter and display to bookmark sidebar"
```

---

## Chunk 3: Integration & Final Verification

### Task 12: Regenerate Xcode project and full verification

**Files:**
- None (verification only)

- [ ] **Step 1: Regenerate Xcode project**

```bash
xcodegen generate
```

- [ ] **Step 2: Build full project**

Run: `xcodebuild build -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -destination "platform=macOS" 2>&1 | grep -E "(BUILD|error:)"`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Run complete test suite**

Run: `xcodebuild test -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -destination "platform=macOS" 2>&1 | tail -10`
Expected: TEST SUCCEEDED with all new + existing tests passing

- [ ] **Step 4: Manual verification checklist**

1. Launch app, open a markdown file
2. Highlight text (Cmd+Shift+H) → verify highlight applied
3. Right-click highlighted text → verify "Add Note" appears in context menu
4. Add a note → hover over highlight → verify tooltip shows note
5. Add bookmark → right-click → "Edit Tags" → add tags
6. Verify tags appear as colored pills in sidebar
7. Use dropdown filter → verify only matching bookmarks shown
8. Restart app → verify notes and tags persist

- [ ] **Step 5: Final commit (if any fixups needed)**

```bash
git add -A
git commit -m "fix: integration adjustments for annotations and tags"
```
