# Window Isolation & File Opening Redesign

Date: 2026-05-22

## Problem

Two independent issues:

1. **Multi-window state leak**: `MarkdownReaderState` is created once at app level and shared across all windows. Opening a new directory in window B changes the file tree, selected file, and bookmark context visible in window A.
2. **Large table rendering**: `LazyVStack` in `MarkdownRenderer` can fail to instantiate/render large markdown table blocks until the user scrolls past them. Content may disappear when the table is in the middle of the viewport.

## Decisions

### Window state is per-window

Each window gets its own `MarkdownReaderState`. Opening a directory/file, selecting a file, changing search, or scrolling in one window must not affect other windows.

Per-window state:
- `fileTree`
- `selectedFileURL`
- `currentDocument`
- `pendingScrollBlockIndex`
- `bodyFontScale` current value
- `SearchState` (already `@State` in `ContentView`)
- scroll/search UI state

Shared state:
- `BookmarkStore`
- `UserDefaults` persistence

`bodyFontScale` is window-local at runtime, but changes persist to UserDefaults so future windows start with the last-used scale.

### Bookmarks are file-level

Bookmarks belong to files, not windows. If two windows show the same file, adding/removing a bookmark in one window should update the bookmark list in the other window. A default bookmark only auto-scrolls during explicit file open/select; changing the default bookmark in another window must not force already-open windows to scroll.

### Opening modes are explicit

Add an `OpenMode` model:

```swift
enum OpenMode: Equatable {
    case empty
    case directory(rootURL: URL)
    case singleFile(URL)
}
```

Directory mode:
- scans a root folder
- shows Files + Bookmarks in the sidebar
- selecting a file preserves directory mode

Single-file mode:
- opens only one Markdown file
- does not scan the parent folder
- sidebar stays visible but shows only Bookmarks

The app persists the last open mode so session restore can distinguish “selected from a directory” from “opened as a single file.”

### Session restore

Only the first default window restores the last session. Subsequent Cmd+N windows and programmatically opened windows start empty or with their explicit open request.

Persisted state:
- `lastOpenModeKey`: `directory` or `singleFile`
- `lastFolderKey`
- `lastFileKey`

Restore rules:
- `directory`: reopen folder, then reselect last file if valid
- `singleFile`: reopen file without scanning parent folder
- no mode key: use backward-compatible behavior, preferring folder+selected file when both exist

### Commands target the frontmost window

Global `NotificationCenter` command broadcasts are removed. Menu commands use `@FocusedValue` (preferably scene-focused values) so Cmd+F / Cmd+O affect only the frontmost window.

Commands:
- Cmd+F: toggle search in current window
- Cmd+O: open single file in current window
- Open Folder: open directory in current window (toolbar/menu, no required shortcut)
- Cmd+Shift+O: open file or folder in a new independent window
- Cmd+N: create new empty window

### Open With / URL handling

File URLs and `goatmarkdown://open?path=...` requests should not mutate an unrelated existing window. They should open through an explicit `OpenRequest` in a non-restoring window.

### Large block rendering

Replace document-level `LazyVStack` with `VStack`. Typical documents in this app are small enough for eager block rendering, and correctness is more important than virtualizing block containers. Future performance work can target individual heavy blocks instead.

## Architecture

Current:

```
GoatMarkdownApp
  └─ shared MarkdownReaderState
       └─ all ContentView windows
```

Proposed:

```
GoatMarkdownApp
  ├─ shared BookmarkStore
  ├─ WindowSessionCoordinator
  ├─ default WindowGroup -> ContentView(bookmarkStore, coordinator)
  └─ WindowGroup(for: OpenRequest.self) -> ContentView(bookmarkStore, coordinator, openRequest)

ContentView
  ├─ @State private var state: MarkdownReaderState?
  ├─ @State private var search: SearchState
  └─ initializes MarkdownReaderState once per window
```

The shared `BookmarkStore` is passed explicitly to each `ContentView` and then into each `MarkdownReaderState`. This avoids environment timing issues when creating a `@State` reference object from injected dependencies.

## Files Affected

| File | Change |
|------|--------|
| `GoatMarkdownApp.swift` | Own shared `BookmarkStore`, add `WindowSessionCoordinator`, add value-based window group, add focused commands |
| `ContentView.swift` | Own per-window `MarkdownReaderState`, publish focused command actions, handle open requests |
| `MarkdownReaderState.swift` | Add `OpenMode`, `OpenRequest`, injected `BookmarkStore`, mode persistence, single-file open |
| `FileBrowserSidebar.swift` | Show file tree only in directory mode; show bookmarks-only in single-file mode |
| `BookmarkSidebarSection.swift` | Ensure bookmarks-only sidebar works standalone |
| `MarkdownRenderer.swift` | `LazyVStack` -> `VStack` |
| `GoatMarkdownTests/MarkdownReaderStateBookmarkTests.swift` | Shared bookmark + independent state tests |
| `GoatMarkdownTests/MarkdownReaderStateFontScaleTests.swift` | Update state initialization |
| `README.md` | Document new opening/window behavior |

## Out of Scope

- Tabs inside a window
- Multiple root directories in one window
- File watching / auto reload
- Per-window persistent restoration of every window
- Performance optimization for very large documents beyond removing `LazyVStack`
