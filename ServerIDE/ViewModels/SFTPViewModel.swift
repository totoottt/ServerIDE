import Foundation
import Combine

@MainActor
final class SFTPViewModel: ObservableObject {
    @Published var currentPath = "."
    @Published var files: [RemoteFile] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var status = ""
    let server: ServerProfile

    init(server: ServerProfile) { self.server = server }

    func load(_ path: String? = nil) {
        guard !isLoading else { return }
        let target = path ?? currentPath
        isLoading = true
        errorMessage = nil
        Task {
            defer { isLoading = false }
            do { try await refresh(target) }
            catch { errorMessage = error.localizedDescription }
        }
    }
    private func refresh(_ target: String) async throws {
        let reply = try await RemoteFileBridge.call(["op": "list", "path": target], server: server)
        files = (reply.files ?? []).sorted {
            if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        currentPath = reply.path ?? target
    }
    func openDirectory(_ file: RemoteFile) { if file.isDirectory { load(file.path) } }
    func goUp() {
        guard currentPath != "/" else { return }
        let parent = (currentPath as NSString).deletingLastPathComponent
        load(parent.isEmpty ? "/" : parent)
    }
    static func validName(_ name: String) -> Bool {
        !name.isEmpty && name != "." && name != ".." && !name.contains("/") && !name.contains("\0") && name.utf8.count <= 255
    }
    func create(name: String, directory: Bool) {
        guard Self.validName(name) else { errorMessage = "Enter a single valid file or folder name."; return }
        let path = (currentPath as NSString).appendingPathComponent(name)
        mutate(["op": directory ? "mkdir" : "create", "path": path])
    }
    func rename(_ file: RemoteFile, to name: String) {
        guard Self.validName(name) else { errorMessage = "Enter a single valid name."; return }
        mutate(["op": "rename", "path": file.path,
                "destination": (currentPath as NSString).appendingPathComponent(name)])
    }
    func delete(_ file: RemoteFile) { mutate(["op": "delete", "path": file.path]) }

    private func mutate(_ arguments: [String: Any]) {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        Task {
            defer { isLoading = false }
            do {
                _ = try await RemoteFileBridge.call(arguments, server: server)
                try await refresh(currentPath)
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func download(_ file: RemoteFile) {
        guard !isLoading, !file.isDirectory else { return }
        isLoading = true
        errorMessage = nil
        Task {
            defer { isLoading = false }
            do {
                let reply = try await RemoteFileBridge.call(["op": "read", "path": file.path], server: server)
                guard let encoded = reply.data, let data = Data(base64Encoded: encoded) else {
                    throw RemoteFileFailure(message: "Invalid download response")
                }
                let base = try LocalFilesStore.downloads()
                let folder = base.appendingPathComponent(UUID().uuidString, isDirectory: true)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
                let destination = folder.appendingPathComponent(file.name)
                try data.write(to: destination, options: [.atomic, .completeFileProtection])
                status = "Downloaded \(file.name). Available in Files → On My iPhone → ServerIDE → Downloads."
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func upload(_ url: URL, directory: Bool) {
        guard !isLoading, currentPath.hasPrefix("/") else { return }
        isLoading = true
        errorMessage = nil
        let destinationFolder = currentPath
        Task {
            let granted = url.startAccessingSecurityScopedResource()
            defer {
                if granted { url.stopAccessingSecurityScopedResource() }
                isLoading = false
            }
            var uploaded = 0
            do {
                let sourceInfo = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
                guard sourceInfo.isSymbolicLink != true, (sourceInfo.isDirectory == true) == directory else {
                    throw RemoteFileFailure(message: "Selected item type does not match; symbolic links are not uploaded.")
                }
                guard Self.validName(url.lastPathComponent) else { throw RemoteFileFailure(message: "Invalid source name") }
                let remoteRoot = (destinationFolder as NSString).appendingPathComponent(url.lastPathComponent)
                if !directory {
                    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard size <= RemoteFileBridge.maxBytes else { throw RemoteFileFailure(message: "Maximum file size is 5 MiB.") }
                    let data = try Data(contentsOf: url)
                    try await RemoteFileBridge.upload(data, destination: remoteRoot, server: server)
                    uploaded = 1
                } else {
                    let items = try LocalFilesStore.folderUploadItems(in: url, maxFileBytes: RemoteFileBridge.maxBytes)
                    _ = try await RemoteFileBridge.call(["op": "mkdir", "path": remoteRoot], server: server)
                    for (child, relative, isDirectory) in items.sorted(by: { $0.1 < $1.1 }) {
                        let destination = (remoteRoot as NSString).appendingPathComponent(relative)
                        if isDirectory {
                            _ = try await RemoteFileBridge.call(["op": "mkdir", "path": destination], server: server)
                        } else {
                            let data = try Data(contentsOf: child)
                            try await RemoteFileBridge.upload(data, destination: destination, server: server)
                            uploaded += 1
                            status = "Uploaded \(uploaded) files…"
                        }
                    }
                }
                status = "Upload complete: \(uploaded) file(s). Existing remote items were not replaced."
                try await refresh(destinationFolder)
            } catch {
                errorMessage = "\(error.localizedDescription)\nUploaded \(uploaded) files. Any completed files or created folders remain on the server."
            }
        }
    }
}

enum LocalFilesStore {
    static func prepare() throws {
        let folder = try downloads()
        let welcome = folder.appendingPathComponent("Welcome.txt")
        if !FileManager.default.fileExists(atPath: welcome.path) {
            try Data("ServerIDE Downloads\nFiles downloaded from your servers appear here.\nThis is local storage, not a live remote server mount.\n".utf8)
                .write(to: welcome, options: [.withoutOverwriting])
        }
    }
    // Finish enumeration synchronously before any SSH await. NSEnumerator's
    // Sequence.makeIterator is marked noasync in the Apple SDK; no enumerator
    // or iterator escapes this function or remains alive across suspension.
    static func folderUploadItems(in url: URL, maxFileBytes: Int) throws -> [(URL, String, Bool)] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .isRegularFileKey, .fileSizeKey]
        var enumerationError: Error?
        guard let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: keys,
            errorHandler: { _, error in
                enumerationError = error
                return false
            }
        ) else { throw RemoteFileFailure(message: "Cannot read this folder.") }
        var items: [(URL, String, Bool)] = []
        var totalBytes = 0
        let prefix = url.standardizedFileURL.path + "/"
        while let child = enumerator.nextObject() as? URL {
            let info = try child.resourceValues(forKeys: Set(keys))
            guard info.isSymbolicLink != true else { throw RemoteFileFailure(message: "Folder contains symbolic links; upload cancelled before transfer.") }
            guard info.isRegularFile == true || info.isDirectory == true else { continue }
            let normalized = child.standardizedFileURL.path
            guard normalized.hasPrefix(prefix) else { throw RemoteFileFailure(message: "Invalid folder path") }
            let relative = String(normalized.dropFirst(prefix.count))
            let size = info.fileSize ?? 0
            guard info.isDirectory == true || size <= maxFileBytes else { throw RemoteFileFailure(message: "A file exceeds the upload size limit.") }
            if info.isDirectory != true { totalBytes += size }
            items.append((child, relative, info.isDirectory == true))
            guard items.count <= 200 && totalBytes <= 20 * 1024 * 1024 else {
                throw RemoteFileFailure(message: "Folder upload limit: 200 entries and 20 MiB total.")
            }
        }
        if let enumerationError { throw enumerationError }
        return items
    }

    static func downloads() throws -> URL {
        let documents = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let downloads = documents.appendingPathComponent("Downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
        return downloads
    }
}
