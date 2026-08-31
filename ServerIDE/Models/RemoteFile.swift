import Foundation

struct RemoteFile: Identifiable, Hashable, Decodable, Sendable {
    var id: String { path }
    let name: String
    let path: String
    let isDirectory: Bool
    let size: UInt64?
    var modified: Double? = nil
    var permissions: String? = nil

    var icon: String {
        if isDirectory { return "folder.fill" }

        switch (name as NSString).pathExtension.lowercased() {
        case "py": return "chevron.left.forwardslash.chevron.right"
        case "js", "ts": return "curlybraces"
        case "json", "yaml", "yml": return "doc.text"
        case "html": return "globe"
        case "sh": return "terminal"
        default: return "doc"
        }
    }
}
