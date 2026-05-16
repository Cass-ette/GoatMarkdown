import SwiftUI

extension Notification.Name {
    static let toggleSearch = Notification.Name("toggleSearch")
    static let openFileCommand = Notification.Name("openFileCommand")
}

@main
struct GoatMarkdownApp: App {
    @State private var state = MarkdownReaderState()
    @State private var hasHandledInitialURL = false

    var body: some Scene {
        WindowGroup {
            ContentView(state: state)
                .task {
                    try? await Task.sleep(for: .milliseconds(300))
                    if !hasHandledInitialURL {
                        state.restoreLastSession()
                    }
                }
                .onOpenURL { url in
                    hasHandledInitialURL = true
                    if url.scheme == "file" {
                        state.handleFileURL(url)
                    } else {
                        state.handleExternalURL(url)
                    }
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1000, height: 700)
        .commands {
            CommandMenu("Find") {
                Button("Find...") {
                    NotificationCenter.default.post(name: .toggleSearch, object: nil)
                }
                .keyboardShortcut("f")
            }
            CommandGroup(after: .newItem) {
                Button("Open File...") {
                    NotificationCenter.default.post(name: .openFileCommand, object: nil)
                }
                .keyboardShortcut("o")
            }
        }
    }
}
