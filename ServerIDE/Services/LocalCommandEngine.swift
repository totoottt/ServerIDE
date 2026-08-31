import Foundation

/// A bounded Documents command interpreter, not a shell or Python runtime.
final class LocalCommandEngine {
    let root: URL
    private(set) var directory: URL
    private let manager = FileManager.default
    var prompt: String { "Documents" + String(directory.path.dropFirst(root.path.count)) + "$" }

    init(root: URL) throws {
        self.root = root.resolvingSymlinksInPath().standardizedFileURL
        directory = self.root
        try manager.createDirectory(at: self.root, withIntermediateDirectories: true)
    }
    func resolve(_ value: String) throws -> URL {
        let candidate = (value.hasPrefix("/") ? root.appendingPathComponent(String(value.dropFirst())) : directory.appendingPathComponent(value)).standardizedFileURL
        guard candidate.path == root.path || candidate.path.hasPrefix(root.path + "/") else {
            throw RemoteFileFailure(message: "Access outside app Documents is not allowed.")
        }

        // `resolvingSymlinksInPath()` does not reliably resolve a symbolic-link
        // ancestor when the final path does not exist. Inspect every existing
        // path component so `outside/new-file` cannot escape through `outside`.
        var componentURL = root
        let relative = String(candidate.path.dropFirst(root.path.count))
        for component in relative.split(separator: "/") {
            componentURL.appendPathComponent(String(component))
            guard let attributes = try? manager.attributesOfItem(atPath: componentURL.path) else { break }
            if attributes[.type] as? FileAttributeType == .typeSymbolicLink {
                throw RemoteFileFailure(message: "Symbolic links are not supported by local commands.")
            }
        }
        let url = candidate.resolvingSymlinksInPath()
        guard url.path == root.path || url.path.hasPrefix(root.path + "/") else {
            throw RemoteFileFailure(message: "Access outside app Documents is not allowed.")
        }
        return url
    }
    static func arguments(_ line: String) throws -> [String] {
        var words: [String] = [], current = ""
        var quote: Character?, escaped = false, started = false
        for character in line {
            if escaped { current.append(character); escaped = false; started = true }
            else if character == "\\", quote != "'" { escaped = true; started = true }
            else if let delimiter = quote {
                if character == delimiter { quote = nil } else { current.append(character) }
            } else if character == "\"" || character == "'" { quote = character; started = true }
            else if character.isWhitespace {
                if started { words.append(current); current = ""; started = false }
            } else { current.append(character); started = true }
        }
        guard quote == nil, !escaped else { throw RemoteFileFailure(message: "Close the quote or finish the escape.") }
        if started { words.append(current) }
        return words
    }
    func run(_ line: String) throws -> String {
        let words = try Self.arguments(line)
        guard let command = words.first else { return "" }
        let args = Array(words.dropFirst())
        func count(_ expected: Int) throws {
            guard args.count == expected else { throw RemoteFileFailure(message: "\(command) expects \(expected) argument(s). Quote names containing spaces.") }
        }
        switch command {
        case "help":
            return "Local Documents commands: pwd, ls [-a] [path], cd <path>, cat <file>, mkdir <name>, touch <name>, cp <file> <new>, mv <path> <new>, rm <path>, echo <text>, clear.\nrm moves to .Trash. No recursive delete, shell pipelines, Python, package installation or SSH here."
        case "pwd": try count(0); return "/" + directory.path.dropFirst(root.path.count).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        case "echo": return args.joined(separator: " ")
        case "clear": try count(0); return ""
        case "cd":
            try count(1)
            let target = try resolve(args[0])
            guard try target.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else { throw RemoteFileFailure(message: "Not a directory.") }
            directory = target; return prompt
        case "ls":
            let paths = args.filter { $0 != "-a" }
            guard paths.count <= 1 else { throw RemoteFileFailure(message: "Use ls [-a] [path].") }
            let target = try resolve(paths.first ?? ".")
            let options: FileManager.DirectoryEnumerationOptions = args.contains("-a") ? [] : [.skipsHiddenFiles]
            let rows = try manager.contentsOfDirectory(at: target, includingPropertiesForKeys: [.isDirectoryKey], options: options)
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            let lines = try rows.prefix(500).map { url in
                let isDirectory = try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
                return url.lastPathComponent + (isDirectory ? "/" : "")
            }
            return lines.joined(separator: "\n") + (rows.count > 500 ? "\n[First 500 entries shown]" : "")
        case "cat":
            try count(1)
            let file = try resolve(args[0])
            let info = try file.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard info.isRegularFile == true, (info.fileSize ?? 0) <= 1_048_576 else { throw RemoteFileFailure(message: "cat supports regular UTF-8 files up to 1 MiB.") }
            return try String(contentsOf: file, encoding: .utf8)
        case "mkdir", "touch":
            try count(1)
            let target = try resolve(args[0])
            if command == "mkdir" { try manager.createDirectory(at: target, withIntermediateDirectories: false) }
            else { try Data().write(to: target, options: [.withoutOverwriting]) }
            return "Created \(target.lastPathComponent)"
        case "cp", "mv":
            try count(2)
            let source = try resolve(args[0]), destination = try resolve(args[1])
            guard source != root, destination != root else { throw RemoteFileFailure(message: "Cannot move or replace Documents.") }
            if command == "cp" {
                let info = try source.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                guard info.isRegularFile == true, (info.fileSize ?? 0) <= 20 * 1024 * 1024 else { throw RemoteFileFailure(message: "cp supports regular files up to 20 MiB.") }
                try manager.copyItem(at: source, to: destination)
            } else { try manager.moveItem(at: source, to: destination) }
            return "Done. Existing destinations are never replaced."
        case "rm":
            try count(1)
            let source = try resolve(args[0]), trash = try resolve("/.Trash")
            guard source != root, source != trash, !source.path.hasPrefix(trash.path + "/") else {
                throw RemoteFileFailure(message: "Cannot remove Documents or its trash.")
            }
            try manager.createDirectory(at: trash, withIntermediateDirectories: true)
            let destination = trash.appendingPathComponent(UUID().uuidString + "-" + source.lastPathComponent)
            try manager.moveItem(at: source, to: destination)
            return "Moved to /.Trash/\(destination.lastPathComponent). Restore using mv."
        default: throw RemoteFileFailure(message: "Unsupported local command: \(command). Type help. Use the Terminal tab for Ubuntu SSH commands.")
        }
    }
}
