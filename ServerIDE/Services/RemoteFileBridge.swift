import Foundation

struct RemoteFileReply: Decodable, Sendable {
    let ok: Bool
    let error: String?
    let path: String?
    let files: [RemoteFile]?
    let data: String?
    let sha256: String?
}

struct RemoteFileFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum RemoteFileBridge {
    static let maxBytes = 5 * 1024 * 1024
    static func command(_ arguments: [String: Any]) throws -> String {
        guard let url = Bundle.main.url(forResource: "remote_files", withExtension: "py") else {
            throw RemoteFileFailure(message: "Remote file helper is missing from this build.")
        }
        let script = try String(contentsOf: url, encoding: .utf8)
        let payload = try JSONSerialization.data(withJSONObject: arguments).base64EncodedString()
        return "python3 -c \(SSHConnectionManager.shellQuote(script)) \(SSHConnectionManager.shellQuote(payload))"
    }
    static func decode(_ output: String) throws -> RemoteFileReply {
        guard let data = output.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8),
              let result = try? JSONDecoder().decode(RemoteFileReply.self, from: data) else {
            throw RemoteFileFailure(message: "Remote helper returned an invalid response. This feature requires Python 3 on the server.")
        }
        guard result.ok else { throw RemoteFileFailure(message: result.error ?? "Remote operation failed") }
        return result
    }
    @MainActor static func call(_ arguments: [String: Any], server: ServerProfile) async throws -> RemoteFileReply {
        let request = try command(arguments)
        let output = try await SSHConnectionManager.shared.execute(request, on: server)
        return try decode(output)
    }
    @MainActor static func upload(_ data: Data, destination: String, server: ServerProfile) async throws {
        _ = try await transfer(data, destination: destination, expectedSHA256: nil, server: server)
    }
    @MainActor static func saveText(_ text: String, destination: String, expectedSHA256: String, server: ServerProfile) async throws -> String {
        try await transfer(Data(text.utf8), destination: destination, expectedSHA256: expectedSHA256, server: server) ?? ""
    }
    @MainActor private static func transfer(_ data: Data, destination: String, expectedSHA256: String?, server: ServerProfile) async throws -> String? {
        guard data.count <= maxBytes else { throw RemoteFileFailure(message: "Maximum file size is 5 MiB.") }
        let parent = (destination as NSString).deletingLastPathComponent
        let temporary = (parent as NSString).appendingPathComponent(".serveride-upload-" + UUID().uuidString)
        var commands = [try command(["op": "uploadStart", "path": temporary])]
        for offset in stride(from: 0, to: data.count, by: 12288) {
            let chunk = data.subdata(in: offset..<min(offset + 12288, data.count))
            commands.append(try command(["op": "uploadChunk", "path": temporary, "data": chunk.base64EncodedString()]))
        }
        let backup: String?
        if let expectedSHA256 {
            let backupPath = (parent as NSString).appendingPathComponent(".serveride-backup-" + UUID().uuidString)
            backup = backupPath
            commands.append(try command(["op": "uploadReplace", "path": temporary, "destination": destination,
                                         "size": data.count, "backup": backupPath, "expectedSHA256": expectedSHA256]))
        } else {
            backup = nil
            commands.append(try command(["op": "uploadFinish", "path": temporary, "destination": destination, "size": data.count]))
        }
        let cleanup = try command(["op": "uploadCancel", "path": temporary])
        try await SSHConnectionManager.shared.executeFileSequence(commands, cleanup: cleanup, on: server)
        return backup
    }
}
