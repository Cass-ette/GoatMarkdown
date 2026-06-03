# Highlighter Feature Design

## Overview

Add a macOS-native text highlighting feature to GoatMarkdown, allowing users to mark text with 5 preset colors (yellow, green, blue, pink, purple). Highlights persist across sessions via JSON sidecar files.

## User Interaction

### Primary Flow: Selection Popover
1. User selects text in rendered Markdown
2. A small toolbar appears above the selection with 5 color buttons
3. User clicks a color → text gets highlighted with that color
4. Clicking the same color again on highlighted text removes the highlight

### Secondary Flow: Keyboard Shortcut
1. User selects text
2. Press `Cmd+Shift+H` → applies default yellow highlight
3. Press again on highlighted text → removes highlight

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
        // Returns semi-transparent background colors
    }
}
```

### Highlight Struct
```swift
struct Highlight: Codable, Equatable, Identifiable {
    let id: UUID
    let blockIndex: Int      // Which markdown block
    let rangeStart: Int      // Character offset start
    let rangeEnd: Int        // Character offset end
    let color: HighlightColor
}
```

### Persistence Format (JSON Sidecar)
For file `/path/to/document.md`, highlights stored in `/path/to/document.md.highlights.json`:

```json
{
  "highlights": [
    {
      "id": "uuid-here",
      "blockIndex": 3,
      "rangeStart": 12,
      "rangeEnd": 45,
      "color": "yellow"
    }
  ],
  "version": 1
}
```

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

**3. TextSelectionHandler**
- Detects text selection events in rendered Markdown
- Extracts `(blockIndex, character range)` from selection
- Shows/hides color picker popover

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
4. Merge with search highlighting (search = higher priority, different opacity)

### Selection Detection
- SwiftUI doesn't provide native selection change callbacks for `Text` views
- **Approach**: Use `.onContinuousHover` + `.gesture(DragGesture)` to detect mouse-up after drag
- On mouse-up: read `NSApp.keyWindow?.firstResponder` if it's a text view, get `selectedRange`
- Map `NSRange` back to `(blockIndex, textIndex, character range)` using visible text cache
- **Fallback**: If selection detection proves complex, start with keyboard-only (`Cmd+Shift+H`) and defer popover to future iteration

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
   - Highlights loaded per document URL
   - Changes in one window don't affect others until reload

## Testing Strategy

### Unit Tests
- `HighlightStoreTests`: JSON encoding/decoding, file I/O
- `HighlightStateTests`: add/remove/toggle/find operations
- `HighlightRenderingTests`: character range → background color application

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
- `GoatMarkdown/HighlightColorPicker.swift`
- `GoatMarkdownTests/HighlightStoreTests.swift`
- `GoatMarkdownTests/HighlightStateTests.swift`

## Files to Modify
- `GoatMarkdown/MarkdownRenderer.swift` — add highlight rendering
- `GoatMarkdown/MarkdownReaderState.swift` — integrate HighlightState
- `GoatMarkdown/ContentView.swift` — add keyboard shortcut
- `README.md` — document highlighting feature
