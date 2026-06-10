# Annotations and Tags Design

**Date:** 2026-06-10  
**Status:** Approved  
**Features:** Highlight annotations (notes) and bookmark tags

## Overview

Extend GoatMarkdown's existing highlight and bookmark systems to support:
1. **Highlight Annotations**: Add optional text notes to highlights
2. **Bookmark Tags**: Add user-defined tags to bookmarks with filtering

## Goals

- Enable users to annotate highlighted text with personal notes
- Allow tagging bookmarks for better organization
- Maintain minimal UI overhead while adding rich metadata
- Keep existing highlight/bookmark workflows intact

## Non-Goals

- Collaborative annotations (single-user only)
- Export/import annotations to external formats
- Advanced tag hierarchies or relationships
- Full-text search across notes

## Design

### 1. Highlight Annotations

#### Data Model Changes

```swift
struct Highlight: Equatable, Codable, Identifiable {
    let id: UUID
    let blockIndex: Int
    let textIndex: Int
    let rangeStart: Int
    let rangeEnd: Int
    let color: HighlightColor
    let createdAt: Date
    var note: String?  // NEW: Optional annotation text
}
```

**Migration:** Existing highlights have `note: nil`. No data migration needed (Codable handles optional fields automatically).

#### User Interaction Flow

1. **Creating highlight:** User selects text → Cmd+Shift+H → Highlight applied (existing behavior, no note yet)
2. **Adding note:** User right-clicks highlight → Context menu shows "Add Note" / "Edit Note" / "Remove Highlight"
3. **Editing note:** Clicking "Add/Edit Note" opens `NoteEditorSheet` (small modal with text field)
4. **Viewing note:** Mouse hover over highlight → Tooltip displays note text
5. **Visual indicator:** Highlights with notes show a small 📝 icon in the top-right corner of the highlighted text

#### UI Components

**NoteEditorSheet:**
- Small modal window (~300x150pt)
- Text field for note input (multiline, max 500 characters)
- Save/Cancel buttons
- Invoked via context menu on highlighted text

**Tooltip Display:**
- Show on hover after 0.5s delay
- Display format: `"[Selected text snippet]\n\nNote: [note text]"`
- Dismiss on mouse out

**Context Menu:**
```
┌─────────────────────────┐
│ ✏️ Add Note             │  (if note == nil)
│ ✏️ Edit Note            │  (if note != nil)
│ ❌ Remove Highlight     │
└─────────────────────────┘
```

#### Implementation Changes

- **Highlight.swift**: Add `note: String?` field
- **MarkdownRenderer.swift**: Add context menu to highlighted text spans
- **NoteEditorSheet.swift** (NEW): Modal for editing notes
- **HighlightState.swift**: Update `toggle()` to preserve notes when re-highlighting
- **MarkdownReaderState.swift**: Add `updateHighlightNote(id: UUID, note: String?)` method

### 2. Bookmark Tags

#### Data Model Changes

```swift
struct Bookmark: Equatable, Codable, Identifiable {
    let id: UUID
    var blockIndex: Int
    var blockSignature: String
    var title: String
    var preview: String
    var isDefault: Bool
    var createdAt: Date
    var tags: [String]  // NEW: User-defined tags
}
```

**Migration:** Existing bookmarks have `tags: []`. No data migration needed.

#### Tag Color Assignment

```swift
class TagRegistry {
    static let shared = TagRegistry()
    
    func color(for tag: String) -> Color {
        // Generate stable color from tag string hash
        let hash = tag.hash
        let hue = Double((hash & 0xFF)) / 255.0
        return Color(hue: hue, saturation: 0.7, brightness: 0.8)
    }
}
```

Each tag gets a consistent color based on its name hash.

#### User Interaction Flow

1. **Adding tags:** User right-clicks bookmark in sidebar → "Edit Tags"
2. **Tag editor:** Opens `TagEditorSheet` with comma-separated input field
3. **Filtering:** Sidebar top shows dropdown: "All Bookmarks" / "#tag1" / "#tag2" ...
4. **Display:** Each bookmark row shows its tags as small colored pills below the title

#### UI Components

**BookmarkSidebarSection Updates:**
```
┌─────────────────────────────────┐
│ Bookmarks                       │
│ ┌─────────────────────────────┐ │
│ │ Filter: All Bookmarks      ▼│ │  ← NEW: Dropdown filter
│ └─────────────────────────────┘ │
│                                 │
│ ⭐ First Heading                │
│    Preview text...              │
│    🟡 重要  🔵 TODO             │  ← NEW: Tag pills
│                                 │
│ ☆ Second Heading                │
│    More text...                 │
│    🟢 已读                      │
└─────────────────────────────────┘
```

**TagEditorSheet:**
- Small modal (~300x120pt)
- Text field: "Enter tags (comma-separated)"
- Auto-suggest dropdown showing previously used tags
- Save/Cancel buttons

**Tag Pill Component:**
- Small rounded rectangle with tag color background
- White text, 10pt font
- 4pt padding, 8pt corner radius

#### Tag Storage & Filtering

**Global Tag List:**
- Automatically collected from all bookmarks across all files
- Stored in BookmarkStore as computed property
- Used to populate filter dropdown

**Filtering Logic:**
```swift
func bookmarks(for filePath: String, tag: String?) -> [Bookmark] {
    let all = byFilePath[filePath] ?? []
    guard let tag = tag else { return all }
    return all.filter { $0.tags.contains(tag) }
}
```

#### Implementation Changes

- **Bookmark.swift**: Add `tags: [String]` field
- **BookmarkStore.swift**: Add `allTags(for:)` method, update filtering
- **BookmarkSidebarSection.swift**: Add dropdown filter, update row layout
- **TagEditorSheet.swift** (NEW): Modal for editing tags
- **TagPillView.swift** (NEW): Reusable colored tag pill component
- **TagRegistry.swift** (NEW): Singleton for consistent tag colors

## Data Persistence

Both features use existing `Codable` persistence via `UserDefaults`:
- `Highlight` persisted by `HighlightStore` (storageKey: `"highlights.byFilePath.v1"`)
- `Bookmark` persisted by `BookmarkStore` (storageKey: `"bookmarks.byFilePath.v1"`)

No migration needed—optional fields default to `nil`/`[]`.

## Testing Strategy

**Manual Testing:**
1. Add note to existing highlight → verify tooltip display
2. Add tags to bookmark → verify filtering works
3. Create new file → verify tags/notes persist across app restarts
4. Right-click interactions → verify context menus appear correctly

**Unit Tests:**
1. `Highlight` with/without notes serialization (Codable)
2. `Bookmark` with/without tags serialization
3. `TagRegistry.color(for:)` produces stable colors
4. Tag filtering logic in `BookmarkStore`

## Migration & Rollback

**Forward compatibility:** Old app versions ignore new fields (Codable defaults).  
**Backward compatibility:** New app reads old data (treats missing fields as `nil`/`[]`).  
**Rollback:** Removing features requires no data migration—unused fields remain in storage but are ignored.

## Open Questions

None—design approved and ready for implementation.
