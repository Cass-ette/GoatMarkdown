import SwiftUI

@main
struct GoatMarkdownApp: App {
    @State private var state = MarkdownReaderState()

    var body: some Scene {
        WindowGroup {
            ContentView(state: state)
                .onAppear {
                    state.restoreLastSession()
                }
                .onOpenURL { url in
                    state.handleExternalURL(url)
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1000, height: 700)
    }
}
