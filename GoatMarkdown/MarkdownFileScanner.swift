import Foundation

final class MarkdownFileScanner {
    private let fileManager: FileManager
    private static let markdownExtensions: Set<String> = ["md", "markdown"]

    init(fileManager: FileManager) {
        self.fileManager = fileManager
    }

    func scan(root: URL) throws -> FileNode {
        let name = root.lastPathComponent
        let children = try scanDirectory(root, basePath: root.path)
        return FileNode(
            id: root.path,
            name: name,
            url: root,
            isDirectory: true,
            children: children
        )
    }

    private func scanDirectory(_ directory: URL, basePath: String) throws -> [FileNode] {
        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey]
        )

        var nodes: [FileNode] = []

        for url in contents {
            let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
            let isDir = resourceValues.isDirectory ?? false

            if isDir {
                let children = try scanDirectory(url, basePath: basePath)
                if !children.isEmpty {
                    nodes.append(FileNode(
                        id: url.path,
                        name: url.lastPathComponent,
                        url: url,
                        isDirectory: true,
                        children: children
                    ))
                }
            } else if Self.isMarkdown(url) {
                nodes.append(FileNode(
                    id: url.path,
                    name: url.lastPathComponent,
                    url: url,
                    isDirectory: false,
                    children: []
                ))
            }
        }

        nodes.sort { a, b in
            switch (a.isDirectory, b.isDirectory) {
            case (true, false): return true
            case (false, true): return false
            default: return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
        }

        return nodes
    }

    private static func isMarkdown(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return markdownExtensions.contains(ext)
    }
}
