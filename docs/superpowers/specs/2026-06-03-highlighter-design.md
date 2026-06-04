# Highlighter Feature Design

## Overview

Add a macOS-native text highlighting feature to GoatMarkdown, allowing users to mark text with 5 preset colors (yellow, green, blue, pink, purple). Highlights persist across sessions via JSON sidecar files.

## User Interaction

### MVP Flow: Keyboard Shortcut Only
1. User selects text in rendered Markdown (native SwiftUI text selection)
2. Press `Cmd+Shift+H` → applies default yellow highlight
3. Press `Cmd+Shift+H` again on highlighted text → removes highlight

### Future Enhancement: Selection Popover
1. User selects text in rendered Markdown
2. A small toolbar appears above the selection with 5 color buttons
3. User clicks a color → text gets highlighted with that color
4. Clicking the same color again on highlighted text removes the highlight

*Note: Selection popover is deferred due to SwiftUI Text API limitations. MVP focuses on keyboard-driven workflow.*

### Visual Feedback
- Highlighted text renders with a semi-transparent background color
- Highlights apply to character ranges within text blocks (similar to search highlighting)
- Multiple highlights can exist in the same block
- Overlapping highlights: later highlight wins (replaces previous)

## Data Model

### HighlightColor Enum
```swift
enum HighlightColor: String, Codable {
    case yellow, green, blue, pink, purple
    
    var swiftUIColor: Color {
        switch self {
        case .yellow: return .yellow.opacity(0.3)
        case .green: return .green.opacity(0.3)
        case .blue: return .blue.opacity(0.3)
        case .pink: return .pink.opacity(0.3)
        case .purple: return .purple.opacity(0.3)
        }
    }
}
```

### Highlight Struct
```swift
struct Highlight: Codable, Equatable, Identifiable {
    let id: UUID
    let blockIndex: Int      // Which markdown block
    let textIndex: Int       // Which text segment within block (e.g., list item index, table cell index)
    let rangeStart: Int      // Character offset start (in rendered plain text of the segment)
    let rangeEnd: Int        // Character offset end
    let color: HighlightColor
    let createdAt: Date      // For potential future "recent highlights" feature
}
```

### Persistence Format (UserDefaults, same as BookmarkStore)
Storage key: `highlights.byFilePath.v1`
Value: `[String: [Highlight]]` — dictionary mapping file path to its highlights list

```json
{
  "/Users/x/docs/notes.md": [
    {
      "id": "uuid-here",
      "blockIndex": 3,
      "textIndex": 0,
      "rangeStart": 12,
      "rangeEnd": 45,
      "color": "yellow"
    }
  ]
}
```

**Storage Decision (User Confirmed)**: Use UserDefaults to match the existing `BookmarkStore` pattern. Avoid filesystem pollution from sidecar files, simpler MVP, consistent with current codebase. Future enhancement can add sidecar export for portability.

## Architecture

### New Components

**1. HighlightStore**
- Reads/writes `.md.highlights.json` files
- Uses same pattern as existing `BookmarkStore`
- Methods: `load(for: URL)`, `save(highlights:for: URL)`

**2. HighlightState** (`@Observable`)
- Holds current document's highlights: `[Highlight]`
- Methods:
  - `add(blockIndex:range:color:)` — adds new highlight
  - `remove(id:)` — removes highlight
  - `find(blockIndex:range:)` — checks if range already highlighted
  - `toggle(blockIndex:range:color:)` — add or remove

**3. TextSelectionHandler (SwiftUI ViewModifier)**
- Wraps `MarkdownRenderer` to detect text selection events
- Tracks current selection state: `@State var selectedRange: (blockIndex: Int, textIndex: Int, range: Range<String.Index>)?`
- Shows/hides `HighlightColorPicker` popover when selection exists
- Interface: `.onHighlightRequest(highlightState: HighlightState)` modifier on `MarkdownRenderer`
- **MVP Scope Decision**: Due to SwiftUI Text selection API limitations, **MVP will ship with keyboard-only interaction (`Cmd+Shift+H`)**. Selection popover will be deferred to a future iteration after we validate feasibility of selection tracking in SwiftUI Text views.

**4. HighlightColorPicker (SwiftUI View)**
- Compact horizontal row of 5 color buttons
- Appears as popover above selected text
- Callback: `onColorSelected: (HighlightColor) -> Void`

### Modified Components

**MarkdownRenderer**
- Accept `highlightState: HighlightState?` binding
- In `cachedText()`: check if character range has highlight → apply background color
- Reuse existing character-range highlighting logic from `SearchState`
- Add selection detection (via `.textSelection(.enabled)` + gesture recognizer)

**MarkdownReaderState**
- Add `@Published var highlightState = HighlightState()`
- Load highlights when document changes (similar to bookmarks)
- Save highlights on highlight state changes

**ContentView**
- Pass `highlightState` to `MarkdownRenderer`
- Register `Cmd+Shift+H` keyboard shortcut

## Implementation Details

### Character Range Mapping
- Highlights are stored as character offsets in the **rendered plain text** (after Markdown parsing)
- Same approach as `SearchState.findMatches()`
- Use `extractSearchableTexts(from:)` pattern to get plain text per block
- Each block can have multiple text segments (e.g., list items)

### Rendering Highlights
In `MarkdownRenderer.cachedText()`:
1. Get plain text for current block/textIndex
2. Query `highlightState.highlights` for matches
3. For each character range with a highlight:
   - Split `AttributedString` at range boundaries
   - Apply `.background(color.swiftUIColor)` to the range
4. **Merge with search highlighting**:
   - If search and highlight overlap, search takes precedence (layer search background on top)
   - Search background: `.yellow.opacity(0.4)` (current match) or `.yellow.opacity(0.2)` (other matches)
   - Highlight background: semi-transparent colors (opacity 0.3)
   - Visual result: search match is clearly visible even over highlights

### Selection Detection (Deferred to Future Iteration)
- SwiftUI doesn't provide native selection change callbacks for `Text` views
- **MVP Decision**: Ship keyboard-only interaction first (`Cmd+Shift+H` applies yellow highlight to current text selection)
- **Future Enhancement**: Explore NSTextView bridging or AppKit-backed selection tracking to enable popover UI
- Selection → highlight flow for MVP:
  1. User selects text in rendered Markdown (native SwiftUI `.textSelection(.enabled)`)
  2. User presses `Cmd+Shift+H`
  3. App reads current focused NSTextView's `selectedRange` via AppKit bridge
  4. Map `NSRange` to `(blockIndex, textIndex, character range)` using block text cache
  5. Apply yellow highlight via `highlightState.add()`

### Popover Positioning
- Use `.popover(isPresented:attachmentAnchor:arrowEdge:)` with `.point()` anchor
- Track selection rect via `NSView.bounds(for:)` from text view
- Show popover above selection (`.top` arrow edge)

## Edge Cases

1. **User edits the Markdown file externally** → character offsets shift → highlights may misalign
   - **Solution**: Document in README that highlights are tied to character positions, not semantic content
   - Future enhancement: store context (surrounding text) for fuzzy matching

2. **Highlight spans across inline Markdown** (e.g., `**bold** text`)
   - Highlights apply to rendered plain text → will work correctly
   
3. **Overlapping highlights**
   - Later highlight replaces earlier (last-write-wins)
   - UI shows only one background color per character

4. **Large documents** (1000+ blocks)
   - Highlights stored flat in JSON → O(n) lookup per block
   - Performance acceptable for <10k highlights (typical use case)
   - If needed: add block-index lookup table

5. **Multi-window isolation**
   - Each `MarkdownReaderState` has own `HighlightState`
   - Highlights loaded per document URL from `.highlights.json`
   - **Sync behavior**: Changes auto-save to JSON immediately → other windows pick up changes on next document reload (explicit user action: reopen file or `Cmd+R` if we add refresh)
   - No automatic cross-window sync (consistent with current bookmark behavior)

## Testing Strategy

### Unit Tests
- `HighlightStoreTests`: JSON encoding/decoding, file I/O, corrupted JSON handling (fallback: ignore and start fresh)
- `HighlightStateTests`: add/remove/toggle/find operations
- `HighlightRenderingLogicTests`: unit test for the `AttributedString` background application logic (not full UI rendering — just the string manipulation)

### Manual Testing
- Select text → click color → verify background appears
- Reopen file → verify highlights persist
- `Cmd+Shift+H` → verify yellow highlight
- Overlapping highlights → verify last color wins
- Search + highlight coexist → verify both visible

## Future Enhancements (Out of Scope)
- Custom colors beyond 5 presets
- Highlight notes/annotations
- Export highlights to separate file
- Sync highlights across devices
- Highlight semantic anchoring (fuzzy match if text shifts)

## Files to Create
- `GoatMarkdown/HighlightColor.swift`
- `GoatMarkdown/Highlight.swift`
- `GoatMarkdown/HighlightState.swift`
- `GoatMarkdown/HighlightStore.swift`
- `GoatMarkdown/HighlightColorPicker.swift` (deferred to future iteration with popover UI)
- `GoatMarkdownTests/HighlightStoreTests.swift`
- `GoatMarkdownTests/HighlightStateTests.swift`
- `GoatMarkdownTests/HighlightRenderingLogicTests.swift`

## Files to Modify
- `GoatMarkdown/MarkdownRenderer.swift` — add highlight rendering
- `GoatMarkdown/MarkdownReaderState.swift` — integrate HighlightState
- `GoatMarkdown/ContentView.swift` — add keyboard shortcut
- `README.md` — document highlighting feature
