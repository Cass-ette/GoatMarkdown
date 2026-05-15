import Foundation

struct FileNode: Identifiable {
    let id: String
    let name: String
    let url: URL
    let isDirectory: Bool
    var children: [FileNode]
}
