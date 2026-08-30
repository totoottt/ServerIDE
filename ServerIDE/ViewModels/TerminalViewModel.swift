import Foundation

@MainActor
final class TerminalViewModel: ObservableObject {
    @Published var command = ""
    @Published var output = ""
    @Published var isRunning = false
    @Published var errorMessage: String?
    @Published var history: [String] = []
    @Published private(set) var currentDirectory = "~"
    private var hasCheckedConnection = false

    let server: ServerProfile

    init(server: ServerProfile) {
        self.server = server
        self.output = "Connecting to \(server.username)@\(server.host)…\n"
    }

    func connect() {
        guard !hasCheckedConnection else { return }
        hasCheckedConnection = true
        Task {
            do {
                try await SSHConnectionManager.shared.connect(to: server)
                let home = try await SSHConnectionManager.shared.execute("pwd", on: server)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !home.isEmpty { currentDirectory = home }
                output += "SSH credentials verified. Working directory: \(currentDirectory)\n"
            } catch {
                errorMessage = error.localizedDescription
                output += "Connection error: \(error.localizedDescription)\n"
            }
        }
    }

    func run() {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isRunning else { return }

        command = ""
        history.removeAll { $0 == trimmed }
        history.insert(trimmed, at: 0)
        history = Array(history.prefix(30))
        isRunning = true
        output += "\n\(server.username)@\(server.host):\(currentDirectory)$ \(trimmed)\n"

        Task {
            do {
                // On a phone, people naturally tap/type an absolute folder path.
                // Treat a bare path as navigation rather than trying to execute the
                // directory itself (which causes the misleading "Permission denied").
                let isBarePath = (trimmed.hasPrefix("/") || trimmed.hasPrefix("~/")) && !trimmed.contains(" ")
                if trimmed == "cd" || trimmed.hasPrefix("cd ") || isBarePath {
                    let changeDirectory: String
                    if trimmed == "cd" { changeDirectory = "cd ~ && pwd" }
                    else if isBarePath { changeDirectory = "cd \(SSHConnectionManager.shellQuote(trimmed)) && pwd" }
                    else { changeDirectory = "\(trimmed) && pwd" }
                    let result = try await SSHConnectionManager.shared.executeTerminal(changeDirectory, on: server)
                    if result.exitCode == 0 {
                        let path = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !path.isEmpty { currentDirectory = path }
                        output += "Working directory: \(currentDirectory)\n"
                    } else {
                        if !result.output.isEmpty { output += result.output + "\n" }
                        output += "[exit \(result.exitCode)]\n"
                    }
                } else {
                    let prefix = currentDirectory == "~" ? "cd ~" : "cd \(SSHConnectionManager.shellQuote(currentDirectory))"
                    let result = try await SSHConnectionManager.shared.executeTerminal("\(prefix) && \(trimmed)", on: server)
                    if !result.output.isEmpty { output += result.output + "\n" }
                    if result.exitCode != 0 { output += "[exit \(result.exitCode)]\n" }
                }
            } catch {
                output += "Error: \(error.localizedDescription)\n"
                errorMessage = error.localizedDescription
            }
            isRunning = false
            if output.count > 300_000 { output = "[Earlier output trimmed]\n" + String(output.suffix(250_000)) }
        }
    }

    func disconnect() {
        Task {
            await SSHConnectionManager.shared.disconnect(from: server)
            output += "\nDisconnected.\n"
        }
    }
}
