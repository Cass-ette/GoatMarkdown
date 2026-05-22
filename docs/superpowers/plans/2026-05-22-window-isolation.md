# Window Isolation Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make each GoatMarkdown window independently manage its directory/file/search/render state while sharing file-level bookmarks, preserving correct session restore, Open With handling, and large-table rendering.

**Architecture:** `GoatMarkdownApp` owns only shared services (`BookmarkStore`, `WindowSessionCoordinator`) and creates independent `ContentView` windows. Each `ContentView` lazily creates one `MarkdownReaderState` for that window, injecting the shared `BookmarkStore`. File opening uses explicit `OpenMode` and `OpenRequest`, while commands route through focused values instead of global notifications.

**Tech Stack:** SwiftUI `WindowGroup(for:)`, `@Observable`, `@State`, `@Bindable`, `@FocusedValue`, AppKit `NSOpenPanel`, XCTest, XcodeGen-generated Xcode project.

---

## Preflight

Before editing code:

- [ ] Confirm repo: `/Users/chenzilve/Projects/goatmarkdown`
- [ ] Confirm current branch/base with `git status` and `git branch --show-current`
- [ ] Confirm scope: only implement window isolation, open modes, focused commands, large-table render fix, and README updates from this plan
- [ ] Do not push without explicit user approval
- [ ] Prefer a feature branch if the current branch is `main` unless user explicitly says to work directly on `main`

---

## Chunk 1: Model State, Persistence, and Rendering

### Files and responsibilities

- `GoatMarkdown/MarkdownReaderState.swift`
  - Defines `OpenMode`, `OpenRequest`, and `WindowSessionCoordinator`.
  - Owns per-window file/document state.
  - Persists/restores last open mode correctly.
- `GoatMarkdown/MarkdownRenderer.swift`
  - Uses eager `VStack` block rendering.
- Tests:
  - `GoatMarkdownTests/MarkdownReaderStateBookmarkTests.swift`
  - `GoatMarkdownTests/MarkdownReaderStateFontScaleTests.swift`

### Task 1: Write tests for open modes, restore modes, independent state, and shared bookmarks

**Files:**
- Modify: `GoatMarkdownTests/MarkdownReaderStateBookmarkTests.swift`
- Modify: `GoatMarkdownTests/MarkdownReaderStateFontScaleTests.swift`

- [ ] **Step 1: Add test helper for state creation**

In `MarkdownReaderStateBookmarkTests`, add a helper near the bottom:

```swift
private func makeState(store: BookmarkStore? = nil) -> MarkdownReaderState {
    MarkdownReaderState(defaults: defaults, bookmarkStore: store ?? BookmarkStore(defaults: defaults))
}
```

Replace existing `MarkdownReaderState(defaults: defaults)` calls with `makeState()`.

- [ ] **Step 2: Add test for shared bookmarks across independent states**

Add:

```swift
func testBookmarksAreSharedAcrossIndependentReaderStates() {
    let store = BookmarkStore(defaults: defaults)
    let first = makeState(store: store)
    let second = makeState(store: store)

    first.openFile(tempFile)
    second.openFile(tempFile)

    first.toggleBookmark(for: 1)

    XCTAssertEqual(second.bookmarkStore.bookmarks(for: tempFile.path).count, 1)
    XCTAssertTrue(second.hasBookmark(for: 1))
}
```

Expected before implementation: compile fails because `openFile(_:)` does not exist and `MarkdownReaderState` does not accept `bookmarkStore:`.

- [ ] **Step 3: Add test for independent selected file state**

Add a second temp file property and create it in `setUp`:

```swift
private var otherTempFile: URL!
```

In `setUp`:

```swift
otherTempFile = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("\(UUID().uuidString)-other.md")
try "# Other\n\nDifferent paragraph"
    .write(to: otherTempFile, atomically: true, encoding: .utf8)
```

In `tearDown`:

```swift
try? FileManager.default.removeItem(at: otherTempFile)
otherTempFile = nil
```

Add:

```swift
func testIndependentStatesKeepSeparateSelectedFiles() {
    let store = BookmarkStore(defaults: defaults)
    let first = makeState(store: store)
    let second = makeState(store: store)

    first.openFile(tempFile)
    second.openFile(otherTempFile)

    XCTAssertEqual(first.selectedFileURL, tempFile)
    XCTAssertEqual(second.selectedFileURL, otherTempFile)
    XCTAssertEqual(first.openMode, .singleFile(tempFile))
    XCTAssertEqual(second.openMode, .singleFile(otherTempFile))
}
```

- [ ] **Step 4: Add test for single-file mode not scanning parent directory**

Add:

```swift
func testOpenFileUsesSingleFileModeWithoutFileTree() {
    let state = makeState()

    state.openFile(tempFile)

    XCTAssertNil(state.fileTree)
    XCTAssertEqual(state.selectedFileURL, tempFile)
    XCTAssertNotNil(state.currentDocument)
    XCTAssertEqual(state.openMode, .singleFile(tempFile))
}
```

- [ ] **Step 5: Add restore mode tests**

Add:

```swift
func testRestoreLastSessionPreservesSingleFileMode() {
    let state = makeState()
    state.openFile(tempFile)

    let restored = makeState()
    restored.restoreLastSession()

    XCTAssertEqual(restored.openMode, .singleFile(tempFile))
    XCTAssertNil(restored.fileTree)
    XCTAssertEqual(restored.selectedFileURL, tempFile)
}
```

Add a temp directory with two markdown files for directory mode:

```swift
func testRestoreLastSessionPreservesDirectoryModeAndSelectedFile() throws {
    let folder = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("\(UUID().uuidString)-folder", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }

    let file = folder.appendingPathComponent("selected.md")
    try "# Selected".write(to: file, atomically: true, encoding: .utf8)

    let state = makeState()
    state.openFolder(folder)
    state.selectFile(file)

    let restored = makeState()
    restored.restoreLastSession()

    XCTAssertEqual(restored.openMode, .directory(rootURL: folder))
    XCTAssertNotNil(restored.fileTree)
    XCTAssertEqual(restored.selectedFileURL, file)
}
```

- [ ] **Step 6: Update font scale tests helper**

In `MarkdownReaderStateFontScaleTests`, add:

```swift
private func makeState() -> MarkdownReaderState {
    MarkdownReaderState(defaults: defaults, bookmarkStore: BookmarkStore(defaults: defaults))
}
```

Replace `MarkdownReaderState(defaults: defaults)` with `makeState()` except the reload case, where use `let reloaded = makeState()`.

- [ ] **Step 7: Run tests to verify RED**

Run:

```bash
xcodebuild test -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -only-testing:GoatMarkdownTests/MarkdownReaderStateBookmarkTests -only-testing:GoatMarkdownTests/MarkdownReaderStateFontScaleTests
```

Expected: FAIL/compile errors for missing `OpenMode`, `openFile(_:)`, and `MarkdownReaderState(defaults:bookmarkStore:)`.

### Task 2: Implement OpenMode, OpenRequest, injected BookmarkStore, and mode persistence

**Files:**
- Modify: `GoatMarkdown/MarkdownReaderState.swift`

- [ ] **Step 1: Add OpenMode and OpenRequest**

After imports, before `@Observable`, add:

```swift
enum OpenMode: Equatable {
    case empty
    case directory(rootURL: URL)
    case singleFile(URL)
}

struct OpenRequest: Codable, Hashable, Identifiable {
    let id: UUID
    let path: String

    init(path: String) {
        self.id = UUID()
        self.path = path
    }
}
```

- [ ] **Step 2: Add openMode and injected BookmarkStore**

Add property:

```swift
var openMode: OpenMode = .empty
```

Change init to:

```swift
init(defaults: UserDefaults = .standard, bookmarkStore: BookmarkStore = BookmarkStore()) {
    self.defaults = defaults
    self.bookmarkStore = bookmarkStore
    self.bodyFontScale = defaults.object(forKey: Self.bodyFontScaleKey) as? Double ?? 1.0
}
```

- [ ] **Step 3: Add persistence keys**

Add:

```swift
private static let lastOpenModeKey = "lastOpenMode"
private static let directoryModeValue = "directory"
private static let singleFileModeValue = "singleFile"
```

- [ ] **Step 4: Update openFolder**

Replace `openFolder(_:)` with:

```swift
func openFolder(_ url: URL) {
    do {
        fileTree = try scanner.scan(root: url)
        openMode = .directory(rootURL: url)
        selectedFileURL = nil
        currentDocument = nil
        pendingScrollBlockIndex = nil
        defaults.set(Self.directoryModeValue, forKey: Self.lastOpenModeKey)
        defaults.set(url.path, forKey: Self.lastFolderKey)
        defaults.removeObject(forKey: Self.lastFileKey)
    } catch {
        fileTree = nil
        openMode = .empty
    }
}
```

- [ ] **Step 5: Add openFile**

Add below `openFolder(_:)`:

```swift
func openFile(_ url: URL) {
    fileTree = nil
    openMode = .singleFile(url)
    defaults.set(Self.singleFileModeValue, forKey: Self.lastOpenModeKey)
    defaults.removeObject(forKey: Self.lastFolderKey)
    selectFile(url)
}
```

- [ ] **Step 6: Keep selectFile mode-neutral**

Leave `selectFile(_:)` mostly as-is. It should set `selectedFileURL`, load `currentDocument`, persist `lastFileKey`, and set `pendingScrollBlockIndex`. It should not change `openMode`.

- [ ] **Step 7: Update URL handlers**

Change `handleFileURL(_:)` non-directory branch to `openFile(url)`.

Change `handleExternalURL(_:)` non-directory branch to `openFile(fileURL)`.

- [ ] **Step 8: Update restoreLastSession**

Replace the function with:

```swift
func restoreLastSession() {
    let lastMode = defaults.string(forKey: Self.lastOpenModeKey)
    let lastFilePath = defaults.string(forKey: Self.lastFileKey)
    let lastFolderPath = defaults.string(forKey: Self.lastFolderKey)

    if lastMode == Self.singleFileModeValue, let lastFilePath {
        let fileURL = URL(fileURLWithPath: lastFilePath)
        guard FileManager.default.fileExists(atPath: lastFilePath) else {
            defaults.removeObject(forKey: Self.lastFileKey)
            return
        }
        openFile(fileURL)
        return
    }

    if lastMode == Self.directoryModeValue, let lastFolderPath {
        restoreDirectory(folderPath: lastFolderPath, selectedFilePath: lastFilePath)
        return
    }

    if let lastFolderPath {
        restoreDirectory(folderPath: lastFolderPath, selectedFilePath: lastFilePath)
    } else if let lastFilePath {
        let fileURL = URL(fileURLWithPath: lastFilePath)
        guard FileManager.default.fileExists(atPath: lastFilePath) else {
            defaults.removeObject(forKey: Self.lastFileKey)
            return
        }
        openFile(fileURL)
    }
}

private func restoreDirectory(folderPath: String, selectedFilePath: String?) {
    let folderURL = URL(fileURLWithPath: folderPath)
    guard FileManager.default.fileExists(atPath: folderPath) else {
        defaults.removeObject(forKey: Self.lastFolderKey)
        return
    }
    openFolder(folderURL)

    guard let selectedFilePath,
          FileManager.default.fileExists(atPath: selectedFilePath) else { return }
    selectFile(URL(fileURLWithPath: selectedFilePath))
}
```

- [ ] **Step 9: Run focused tests to verify GREEN**

Run:

```bash
xcodebuild test -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -only-testing:GoatMarkdownTests/MarkdownReaderStateBookmarkTests -only-testing:GoatMarkdownTests/MarkdownReaderStateFontScaleTests
```

Expected: both suites pass.

- [ ] **Step 10: Commit**

```bash
git add GoatMarkdown/MarkdownReaderState.swift GoatMarkdownTests/MarkdownReaderStateBookmarkTests.swift GoatMarkdownTests/MarkdownReaderStateFontScaleTests.swift
git commit -m "feat: add window-local open modes"
```

### Task 3: Fix large-table rendering

**Files:**
- Modify: `GoatMarkdown/MarkdownRenderer.swift`

- [ ] **Step 1: Replace LazyVStack with VStack**

Change:

```swift
LazyVStack(alignment: .leading, spacing: 12) {
```

to:

```swift
VStack(alignment: .leading, spacing: 12) {
```

- [ ] **Step 2: Run SearchHighlightTests**

Run:

```bash
xcodebuild test -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -only-testing:GoatMarkdownTests/SearchHighlightTests
```

Expected: 5 tests, 0 failures.

- [ ] **Step 3: Commit**

```bash
git add GoatMarkdown/MarkdownRenderer.swift
git commit -m "fix: render markdown blocks eagerly"
```

---

## Chunk 2: Per-Window UI State and Commands

### Files and responsibilities

- `GoatMarkdown/GoatMarkdownApp.swift`
  - Own shared `BookmarkStore` and `WindowSessionCoordinator`.
  - Define focused command values in the same file to avoid Xcode target file-reference issues.
  - Add default and request-based window groups.
- `GoatMarkdown/ContentView.swift`
  - Own one `MarkdownReaderState` per window.
  - Publish focused command actions.
  - Open file/folder in the current window.
  - Open requests passed from a new window.
- `GoatMarkdown/FileBrowserSidebar.swift`
  - Show file tree only in directory mode.

### Task 4: Add coordinator and focused command types in an existing compiled file

**Files:**
- Modify: `GoatMarkdown/GoatMarkdownApp.swift`

- [ ] **Step 1: Add focused command types above GoatMarkdownApp**

At top of `GoatMarkdownApp.swift`, remove `Notification.Name` extension and add:

```swift
struct WindowCommandActions {
    var toggleSearch: () -> Void
    var openFile: () -> Void
    var openFolder: () -> Void
    var openInNewWindow: () -> Void
}

private struct WindowCommandActionsKey: FocusedValueKey {
    typealias Value = WindowCommandActions
}

extension FocusedValues {
    var windowCommandActions: WindowCommandActions? {
        get { self[WindowCommandActionsKey.self] }
        set { self[WindowCommandActionsKey.self] = newValue }
    }
}

@Observable
final class WindowSessionCoordinator {
    private var hasConsumedInitialRestore = false

    func consumeShouldRestoreLastSession() -> Bool {
        guard !hasConsumedInitialRestore else { return false }
        hasConsumedInitialRestore = true
        return true
    }
}
```

No new file is created, so `project.yml`/xcodeproj target membership is not an issue.

- [ ] **Step 2: Add Commands type**

Also add:

```swift
struct GoatMarkdownCommands: Commands {
    @FocusedValue(\.windowCommandActions) private var windowCommandActions

    var body: some Commands {
        CommandMenu("Find") {
            Button("Find...") {
                windowCommandActions?.toggleSearch()
            }
            .keyboardShortcut("f")
            .disabled(windowCommandActions == nil)
        }

        CommandGroup(after: .newItem) {
            Button("Open File...") {
                windowCommandActions?.openFile()
            }
            .keyboardShortcut("o")
            .disabled(windowCommandActions == nil)

            Button("Open Folder...") {
                windowCommandActions?.openFolder()
            }
            .disabled(windowCommandActions == nil)

            Button("Open in New Window...") {
                windowCommandActions?.openInNewWindow()
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
            .disabled(windowCommandActions == nil)
        }
    }
}
```

- [ ] **Step 3: Build to verify command types compile**

Run:

```bash
xcodebuild build -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -configuration Debug
```

Expected: may still fail until `GoatMarkdownApp` uses commands consistently; fix in Task 5 before committing.

### Task 5: Update GoatMarkdownApp to own shared services and window groups

**Files:**
- Modify: `GoatMarkdown/GoatMarkdownApp.swift`

- [ ] **Step 1: Replace app-level shared state**

Change properties to:

```swift
@State private var bookmarkStore = BookmarkStore()
@State private var sessionCoordinator = WindowSessionCoordinator()
```

Remove `@State private var state = MarkdownReaderState()` and `hasHandledInitialURL`.

- [ ] **Step 2: Replace WindowGroup content**

Use two groups:

```swift
WindowGroup {
    ContentView(
        bookmarkStore: bookmarkStore,
        shouldRestoreLastSession: sessionCoordinator.consumeShouldRestoreLastSession()
    )
}
.windowStyle(.titleBar)
.defaultSize(width: 1000, height: 700)

WindowGroup("GoatMarkdown", for: OpenRequest.self) { request in
    ContentView(
        bookmarkStore: bookmarkStore,
        shouldRestoreLastSession: false,
        openRequest: request.wrappedValue
    )
}
.windowStyle(.titleBar)
.defaultSize(width: 1000, height: 700)
```

If the compiler requires a distinct id for the valued group, use:

```swift
WindowGroup(id: "open-request", for: OpenRequest.self) { request in ... }
```

- [ ] **Step 3: Replace commands block**

Replace the existing `.commands { ... }` content with:

```swift
.commands {
    GoatMarkdownCommands()
}
```

Attach it to the default `WindowGroup`. If SwiftUI requires `.commands` once per app scene, put it after both WindowGroups if compiler allows; otherwise attach to the first group.

- [ ] **Step 4: Keep onOpenURL temporarily out**

Do not add `.onOpenURL` in this task. It will be restored in Task 8 after `ContentView` supports `OpenRequest`.

- [ ] **Step 5: Build after ContentView task, not now**

This task depends on the new `ContentView` initializer in Task 6. Do not expect this to build until Task 6 is implemented.

### Task 6: Move MarkdownReaderState ownership into ContentView

**Files:**
- Modify: `GoatMarkdown/ContentView.swift`

- [ ] **Step 1: Change ContentView stored properties and initializer**

Replace:

```swift
@Bindable var state: MarkdownReaderState
@State private var search = SearchState()
@FocusState private var searchFieldFocused: Bool
```

with:

```swift
let bookmarkStore: BookmarkStore
let shouldRestoreLastSession: Bool
let openRequest: OpenRequest?

@State private var state: MarkdownReaderState?
@State private var search = SearchState()
@FocusState private var searchFieldFocused: Bool

init(
    bookmarkStore: BookmarkStore,
    shouldRestoreLastSession: Bool = false,
    openRequest: OpenRequest? = nil
) {
    self.bookmarkStore = bookmarkStore
    self.shouldRestoreLastSession = shouldRestoreLastSession
    self.openRequest = openRequest
}
```

- [ ] **Step 2: Wrap body around lazy state creation**

Replace `var body` with:

```swift
var body: some View {
    Group {
        if let state {
            content(for: state)
        } else {
            ProgressView()
                .task {
                    let created = MarkdownReaderState(bookmarkStore: bookmarkStore)
                    state = created
                    if let openRequest {
                        created.handleFileURL(URL(fileURLWithPath: openRequest.path))
                    } else if shouldRestoreLastSession {
                        created.restoreLastSession()
                    }
                }
        }
    }
}
```

- [ ] **Step 3: Move existing view body into content(for:)**

Add:

```swift
@ViewBuilder
private func content(for state: MarkdownReaderState) -> some View {
    @Bindable var state = state
    NavigationSplitView {
        ...existing sidebar/detail content...
    } detail: {
        ...existing detail content...
    }
    .toolbar { ...existing toolbar... }
    .onKeyPress(.init("/")) { ... }
    .focusedValue(\.windowCommandActions, WindowCommandActions(
        toggleSearch: {
            search.toggle()
            if let doc = state.currentDocument { search.search(in: doc) }
        },
        openFile: { openFilePanel(in: state) },
        openFolder: { openFolderPanel(in: state) },
        openInNewWindow: { openInNewWindowPanel() }
    ))
}
```

Move all existing toolbar/keyPress/search rendering logic into this function. Keep `$state.pendingScrollBlockIndex` working via `@Bindable var state = state`.

- [ ] **Step 4: Remove NotificationCenter receivers**

Delete `.onReceive(NotificationCenter.default.publisher(for: .toggleSearch))` and `.onReceive(NotificationCenter.default.publisher(for: .openFileCommand))`.

- [ ] **Step 5: Update panel helpers**

Change signatures:

```swift
private func openFolderPanel(in state: MarkdownReaderState)
private func openFilePanel(in state: MarkdownReaderState)
private func openInNewWindowPanel()
```

`openFolderPanel(in:)` keeps current directory picker and calls `state.openFolder(url)`.

`openFilePanel(in:)` uses file picker and calls `state.openFile(url)`.

`openInNewWindowPanel()` uses combined picker:

```swift
private func openInNewWindowPanel() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.prompt = "Open in New Window"
    panel.begin { response in
        guard response == .OK, let url = panel.url else { return }
        NSWorkspace.shared.open(URL(string: "goatmarkdown://open?path=\(url.path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? url.path)")!)
    }
}
```

Note: This temporary URL approach reuses `.onOpenURL` in Task 8. If a direct `openWindow(value:)` call is available in `ContentView`, prefer that over `NSWorkspace.shared.open`.

- [ ] **Step 6: Build together with Tasks 4-5**

Run:

```bash
xcodebuild build -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -configuration Debug
```

Expected: resolve compiler errors in `ContentView`/`GoatMarkdownApp` until build succeeds.

- [ ] **Step 7: Run full tests**

Run:

```bash
xcodebuild test -project GoatMarkdown.xcodeproj -scheme GoatMarkdown
```

Expected: all tests pass.

- [ ] **Step 8: Commit**

```bash
git add GoatMarkdown/GoatMarkdownApp.swift GoatMarkdown/ContentView.swift
git commit -m "feat: isolate reader state per window"
```

### Task 7: Make sidebar respect single-file mode

**Files:**
- Modify: `GoatMarkdown/FileBrowserSidebar.swift`
- Modify: `GoatMarkdown/BookmarkSidebarSection.swift` if needed.

- [ ] **Step 1: Extract current body into directorySidebar**

Convert current `body` contents into:

```swift
@ViewBuilder
private var directorySidebar: some View {
    Group {
        ...existing body contents...
    }
}
```

- [ ] **Step 2: Branch on openMode**

Set `body` to:

```swift
var body: some View {
    switch state.openMode {
    case .singleFile:
        bookmarkList
    case .directory, .empty:
        directorySidebar
    }
}
```

In `.empty`, keep the existing "Open a folder to start reading" prompt.

- [ ] **Step 3: Build**

Run:

```bash
xcodebuild build -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -configuration Debug
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add GoatMarkdown/FileBrowserSidebar.swift GoatMarkdown/BookmarkSidebarSection.swift
git commit -m "feat: show bookmarks sidebar for single files"
```

### Task 8: Restore URL/Open With handling through explicit open requests

**Files:**
- Modify: `GoatMarkdown/GoatMarkdownApp.swift`
- Modify: `GoatMarkdown/ContentView.swift` if direct `openWindow` is used.

- [ ] **Step 1: Add onOpenURL to open a request window**

On the default `WindowGroup`, add:

```swift
.onOpenURL { url in
    let request: OpenRequest?
    if url.scheme == "file" {
        request = OpenRequest(path: url.path)
    } else if url.scheme == "goatmarkdown", url.host == "open" {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let path = components?.queryItems?.first(where: { $0.name == "path" })?.value
        request = path.map(OpenRequest.init(path:))
    } else {
        request = nil
    }

    guard let request else { return }
    openWindow(value: request)
}
```

If `openWindow` is not available in `GoatMarkdownApp`, move URL handling into a scene-level wrapper that has `@Environment(\.openWindow)`.

- [ ] **Step 2: Replace `openInNewWindowPanel` with direct openWindow if possible**

Prefer this in `ContentView`:

```swift
@Environment(\.openWindow) private var openWindow
```

Then:

```swift
private func openInNewWindowPanel() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.prompt = "Open in New Window"
    panel.begin { response in
        guard response == .OK, let url = panel.url else { return }
        openWindow(value: OpenRequest(path: url.path))
    }
}
```

If this compiles, remove the temporary `NSWorkspace.shared.open(...)` URL workaround from Task 6.

- [ ] **Step 3: Build and test**

Run:

```bash
xcodebuild build -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -configuration Debug
xcodebuild test -project GoatMarkdown.xcodeproj -scheme GoatMarkdown
```

Expected: build succeeds, tests pass.

- [ ] **Step 4: Commit**

```bash
git add GoatMarkdown/GoatMarkdownApp.swift GoatMarkdown/ContentView.swift
git commit -m "feat: route open requests to new windows"
```

---

## Chunk 3: Docs, Verification, and Manual QA

### Task 9: Update README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update feature list**

Add bullets:

```markdown
- 目录模式和单文件模式：目录模式显示文件树，单文件模式只显示当前文件书签
- 多窗口独立状态：不同窗口可打开不同目录/文件，互不影响
```

- [ ] **Step 2: Update shortcuts table**

Ensure README lists only implemented shortcuts:

```markdown
| `Cmd + N` | 新建空窗口 |
| `Cmd + O` | 在当前窗口打开文件 |
| `Cmd + Shift + O` | 在新窗口打开文件或目录 |
```

If Open Folder has no shortcut, list it as toolbar/menu only, not in shortcut table.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: document independent windows"
```

### Task 10: Full verification

- [ ] **Step 1: Run full tests**

```bash
xcodebuild test -project GoatMarkdown.xcodeproj -scheme GoatMarkdown
```

Expected: all tests pass, 0 failures.

- [ ] **Step 2: Run debug build**

```bash
xcodebuild build -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -configuration Debug
```

Expected: `** BUILD SUCCEEDED **`.

### Task 11: Manual QA

- [ ] **Step 1: Install Debug app**

Ensure app is closed, then:

```bash
APP_PATH=$(find "$HOME/Library/Developer/Xcode/DerivedData" -path "*/Build/Products/Debug/GoatMarkdown.app" -print | tail -1)
rm -rf "/Applications/GoatMarkdown.app"
ditto "$APP_PATH" "/Applications/GoatMarkdown.app"
```

- [ ] **Step 2: Single-file mode**

1. Launch app.
2. Cmd+O, pick a `.md` file.
3. Confirm sidebar shows only Bookmarks.
4. Confirm no parent directory tree appears.
5. Add bookmark; confirm it appears.

- [ ] **Step 3: Directory mode**

1. Use Open Folder toolbar/menu.
2. Pick a directory.
3. Confirm sidebar shows Files + Bookmarks.
4. Select files; confirm only this window changes.

- [ ] **Step 4: Multi-window isolation**

1. Window A: open directory A and file A1.
2. Cmd+Shift+O: open directory/file B in new window.
3. Return to window A.
4. Confirm A still shows directory A/file A1/search state.

- [ ] **Step 5: Shared bookmarks**

1. Open same file in two windows.
2. Add bookmark in A.
3. Confirm B's bookmark list updates.
4. Confirm B does not auto-scroll until bookmark clicked.

- [ ] **Step 6: Large table rendering**

1. Open the problematic large-table markdown.
2. Scroll through the table.
3. Confirm table renders in the middle of viewport without dragging to bottom.

- [ ] **Step 7: Search regression**

1. Search a term with multiple matches.
2. Press Enter repeatedly.
3. Confirm highlight and scroll target advance correctly.

### Task 12: Final status and push

- [ ] **Step 1: Check status**

```bash
git status
git log --oneline -10
```

Expected: clean working tree, expected commits.

- [ ] **Step 2: Ask user before pushing**

Only after explicit user approval:

```bash
git push origin <branch>
```
