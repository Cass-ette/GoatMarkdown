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
                        FileNodeRow(node: tree, onSelect: onSelect)
                    }
                    .listStyle(.sidebar)
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
    let onSelect: (URL) -> Void

    var body: some View {
        if node.isDirectory {
            DisclosureGroup {
                ForEach(node.children) { child in
                    FileNodeRow(node: child, onSelect: onSelect)
                }
            } label: {
                Label(node.name, systemImage: "folder")
            }
        } else {
            Button {
                onSelect(node.url)
            } label: {
                Label(node.name, systemImage: "doc.text")
            }
            .buttonStyle(.plain)
            .tag(node.url)
        }
    }
}
