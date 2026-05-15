import SwiftUI

struct FileBrowserSidebar: View {
    let tree: FileNode?
    @Binding var selectedFileURL: URL?
    let onSelect: (URL) -> Void

    var body: some View {
        Group {
            if let tree {
                if tree.children.isEmpty {
                    Text("No Markdown files found")
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    List(selection: $selectedFileURL) {
                        ForEach(tree.children) { child in
                            FileNodeRow(node: child)
                        }
                    }
                    .listStyle(.sidebar)
                    .onChange(of: selectedFileURL) { _, newURL in
                        if let newURL {
                            onSelect(newURL)
                        }
                    }
                }
            } else {
                Text("Open a folder to start reading")
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
    }
}

struct FileNodeRow: View {
    let node: FileNode

    var body: some View {
        if node.isDirectory {
            DisclosureGroup {
                ForEach(node.children) { child in
                    FileNodeRow(node: child)
                }
            } label: {
                Label(node.name, systemImage: "folder")
            }
        } else {
            Label(node.name, systemImage: "doc.text")
                .tag(node.url)
        }
    }
}
