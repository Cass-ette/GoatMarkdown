import SwiftUI

@main
struct GoatMarkdownApp: App {
    @State private var state = MarkdownReaderState()
    @State private var hasHandledInitialURL = false

    var body: some Scene {
        WindowGroup {
            ContentView(state: state)
                .task {
                    // Delay restore to let onOpenURL fire first on cold launch
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
    }
}
