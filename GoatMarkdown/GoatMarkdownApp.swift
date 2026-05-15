import SwiftUI

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
                    state.showSearch = true
                }
                .keyboardShortcut("f")
            }
            CommandGroup(after: .newItem) {
                Button("Open File...") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = true
                    panel.canChooseDirectories = false
                    panel.allowsMultipleSelection = false
                    panel.allowedContentTypes = [.init(filenameExtension: "md")!, .init(filenameExtension: "markdown")!]
                    panel.prompt = "Open"
                    panel.begin { response in
                        guard response == .OK, let url = panel.url else { return }
                        state.openFolder(url.deletingLastPathComponent())
                        state.selectFile(url)
                    }
                }
                .keyboardShortcut("o")
            }
        }
    }
}
