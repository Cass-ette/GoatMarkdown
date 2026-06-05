import SwiftUI

struct WindowCommandActions {
    var toggleSearch: () -> Void
    var openFile: () -> Void
    var openFolder: () -> Void
    var openInNewWindow: () -> Void
    var toggleHighlight: () -> Void
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

        CommandGroup(after: .textEditing) {
            Button("Highlight") {
                windowCommandActions?.toggleHighlight()
            }
            .keyboardShortcut("h", modifiers: [.command, .shift])
            .disabled(windowCommandActions == nil)
        }
    }
}

@main
struct GoatMarkdownApp: App {
    @State private var bookmarkStore = BookmarkStore()
    @State private var sessionCoordinator = WindowSessionCoordinator()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup {
            ContentView(
                bookmarkStore: bookmarkStore,
                shouldRestoreLastSession: sessionCoordinator.consumeShouldRestoreLastSession()
            )
            .onOpenURL { url in
                guard let request = openRequest(from: url) else { return }
                openWindow(value: request)
            }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1000, height: 700)
        .commands {
            GoatMarkdownCommands()
        }

        WindowGroup("GoatMarkdown", for: OpenRequest.self) { request in
            ContentView(
                bookmarkStore: bookmarkStore,
                shouldRestoreLastSession: false,
                openRequest: request.wrappedValue
            )
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1000, height: 700)
    }

    private func openRequest(from url: URL) -> OpenRequest? {
        if url.scheme == "file" {
            return OpenRequest(path: url.path)
        }
        guard url.scheme == "goatmarkdown", url.host == "open" else { return nil }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let path = components?.queryItems?.first(where: { $0.name == "path" })?.value else { return nil }
        return OpenRequest(path: path)
    }
}
