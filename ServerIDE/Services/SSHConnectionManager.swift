import Foundation

#if canImport(Citadel)
@preconcurrency import Citadel
#endif

enum SSHConnectionError: LocalizedError {
    case missingPassword
    case privateKeyAuthenticationPending
    case dependencyMissing
    case notConnected
    case invalidTextEncoding

    var errorDescription: String? {
        switch self {
        case .missingPassword:
            return "No SSH password is stored for this server."
        case .privateKeyAuthenticationPending:
            return "Private key authentication is not enabled in this build yet."
        case .dependencyMissing:
            return "Citadel is not available in this build."
        case .notConnected:
            return "The SSH connection is not active."
        case .invalidTextEncoding:
            return "The remote file could not be decoded as UTF-8 text."
        }
    }
}

struct SSHCommandResult: Sendable {
    let output: String
    let exitCode: Int
}

/// Swift 6-safe SSH manager for the current MVP.
///
/// Important design choice:
/// We do not cache Citadel's SSHClient inside an actor or isolated object.
/// Each operation opens a short-lived SSH connection, performs its work,
/// then closes it. This avoids Swift 6 sendability/data-race diagnostics
/// from Citadel 0.12.x while keeping the public API compatible.
final class SSHConnectionManager: @unchecked Sendable {
    static let shared = SSHConnectionManager()

    private init() {}

    // MARK: - Client creation

    #if canImport(Citadel)
    private func makeClient(for server: ServerProfile) async throws -> SSHClient {
        guard server.authenticationType == .password else {
            throw SSHConnectionError.privateKeyAuthenticationPending
        }

        guard
            let password = CredentialStore.password(for: server.id),
            !password.isEmpty
        else {
            throw SSHConnectionError.missingPassword
        }

        let settings = SSHClientSettings(
            host: server.host,
            port: server.port,
            authenticationMethod: {
                .passwordBased(
                    username: server.username,
                    password: password
                )
            },
            // MVP behavior. Replace with fingerprint/TOFU validation before release.
            hostKeyValidator: .acceptAnything()
        )

        return try await SSHClient.connect(to: settings)
    }
    #endif

    // MARK: - Connection API compatibility

    func connect(to server: ServerProfile) async throws {
        #if canImport(Citadel)
        let client = try await makeClient(for: server)
        try? await client.close()
        #else
        throw SSHConnectionError.dependencyMissing
        #endif
    }

    func disconnect(from server: ServerProfile) async {
        // No persistent connection is retained in this implementation.
        _ = server
    }

    // MARK: - Commands

    func execute(_ command: String, on server: ServerProfile) async throws -> String {
        #if canImport(Citadel)
        let client = try await makeClient(for: server)

        do {
            let result = try await client.executeCommand(
                command,
                maxResponseSize: 8 * 1024 * 1024,
                mergeStreams: true
            )

            try? await client.close()

            var copy = result
            return copy.readString(length: copy.readableBytes) ?? ""
        } catch {
            try? await client.close()
            throw error
        }
        #else
        throw SSHConnectionError.dependencyMissing
        #endif
    }

    /// Executes a user terminal command while preserving stderr and its exit
    /// status. The wrapper itself exits successfully, so Citadel does not throw
    /// away useful output when the remote command returns a non-zero code.
    func executeTerminal(_ command: String, on server: ServerProfile) async throws -> SSHCommandResult {
        #if canImport(Citadel)
        let client = try await makeClient(for: server)
        let marker = "__SERVERIDE_STATUS_\(UUID().uuidString)__="
        let script = "( \(command) ); serveride_status=$?; printf '\\n\(marker)%s\\n' \"$serveride_status\"; exit 0"
        do {
            var buffer = try await client.executeCommand(
                "sh -lc \(Self.shellQuote(script))",
                maxResponseSize: 8 * 1024 * 1024,
                mergeStreams: true
            )
            try? await client.close()
            let raw = buffer.readString(length: buffer.readableBytes) ?? ""
            return Self.parseTerminalOutput(raw, marker: marker)
        } catch {
            try? await client.close()
            throw error
        }
        #else
        throw SSHConnectionError.dependencyMissing
        #endif
    }

    static func parseTerminalOutput(_ raw: String, marker: String) -> SSHCommandResult {
        guard let range = raw.range(of: marker, options: .backwards) else {
            return SSHCommandResult(output: raw, exitCode: 0)
        }
        let statusText = raw[range.upperBound...].split(whereSeparator: { $0.isNewline }).first.map(String.init) ?? "1"
        let clean = String(raw[..<range.lowerBound]).trimmingCharacters(in: .newlines)
        return SSHCommandResult(output: clean, exitCode: Int(statusText) ?? 1)
    }

    // MARK: - Directory listing

    /// Reuse one connection for all upload chunks. No SSH client crosses an actor boundary.
    func executeFileSequence(_ commands: [String], cleanup: String, on server: ServerProfile) async throws {
        #if canImport(Citadel)
        let client = try await makeClient(for: server)
        var stagingCreated = false
        do {
            for command in commands {
                try Task.checkCancellation()
                var buffer = try await client.executeCommand(command, maxResponseSize: 4 * 1024 * 1024, mergeStreams: true)
                _ = try RemoteFileBridge.decode(buffer.readString(length: buffer.readableBytes) ?? "")
                stagingCreated = true
            }
            try? await client.close()
        } catch {
            if stagingCreated { _ = try? await client.executeCommand(cleanup, maxResponseSize: 4096, mergeStreams: true) }
            try? await client.close()
            throw error
        }
        #else
        throw SSHConnectionError.dependencyMissing
        #endif
    }

    func listDirectory(
        _ path: String,
        on server: ServerProfile
    ) async throws -> [RemoteFile] {
        let quotedPath = Self.shellQuote(path)

        // GNU find is standard on the Ubuntu/Linux servers currently targeted.
        // Output: type<TAB>size<TAB>filename
        let command = """
        find \(quotedPath) -mindepth 1 -maxdepth 1 -printf '%y\\t%s\\t%f\\n' 2>/dev/null
        """

        let output = try await execute(command, on: server)
        var result: [RemoteFile] = []

        for rawLine in output.split(whereSeparator: { $0.isNewline }) {
            let parts = rawLine.split(
                separator: "\t",
                maxSplits: 2,
                omittingEmptySubsequences: false
            )

            guard parts.count == 3 else {
                continue
            }

            let type = String(parts[0])
            let size = UInt64(String(parts[1])) ?? 0
            let name = String(parts[2])

            guard !name.isEmpty, name != ".", name != ".." else {
                continue
            }

            let fullPath: String

            if path == "/" {
                fullPath = "/" + name
            } else if path.hasSuffix("/") {
                fullPath = path + name
            } else {
                fullPath = path + "/" + name
            }

            result.append(
                RemoteFile(
                    name: name,
                    path: fullPath,
                    isDirectory: type == "d",
                    size: size
                )
            )
        }

        return result.sorted {
            if $0.isDirectory != $1.isDirectory {
                return $0.isDirectory && !$1.isDirectory
            }

            return $0.name.localizedCaseInsensitiveCompare($1.name)
                == .orderedAscending
        }
    }

    // MARK: - Text files

    func readTextFile(
        _ path: String,
        on server: ServerProfile
    ) async throws -> String {
        // base64 prevents shell output from altering file contents.
        let command = "base64 -w 0 -- \(Self.shellQuote(path))"
        let encoded = try await execute(command, on: server)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            let data = Data(base64Encoded: encoded),
            let text = String(data: data, encoding: .utf8)
        else {
            throw SSHConnectionError.invalidTextEncoding
        }

        return text
    }

    func writeTextFile(
        _ text: String,
        to path: String,
        on server: ServerProfile
    ) async throws {
        let encoded = Data(text.utf8).base64EncodedString()

        let command = """
        printf '%s' \(Self.shellQuote(encoded)) | base64 -d > \(Self.shellQuote(path))
        """

        _ = try await execute(command, on: server)
    }

    // MARK: - File management

    func createDirectory(
        _ path: String,
        on server: ServerProfile
    ) async throws {
        _ = try await execute(
            "mkdir -p -- \(Self.shellQuote(path))",
            on: server
        )
    }

    func rename(
        from oldPath: String,
        to newPath: String,
        on server: ServerProfile
    ) async throws {
        _ = try await execute(
            "mv -- \(Self.shellQuote(oldPath)) \(Self.shellQuote(newPath))",
            on: server
        )
    }

    func delete(
        _ file: RemoteFile,
        on server: ServerProfile
    ) async throws {
        let command: String

        if file.isDirectory {
            command = "rmdir -- \(Self.shellQuote(file.path))"
        } else {
            command = "rm -- \(Self.shellQuote(file.path))"
        }

        _ = try await execute(command, on: server)
    }

    // MARK: - Helpers

    static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(
            of: "'",
            with: "'\\''"
        ) + "'"
    }
}
