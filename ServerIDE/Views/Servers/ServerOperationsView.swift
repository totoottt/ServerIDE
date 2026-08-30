import SwiftUI

struct ServerOperationsView: View {
    let server: ServerProfile
    @State private var section = "Services"
    @State private var service = "telegrambot"
    @State private var output = ""
    @State private var running = false
    @State private var pendingAction: String?

    private var validService: Bool {
        !service.isEmpty && service.count <= 128 &&
        service.unicodeScalars.allSatisfy {
            CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.@:-").contains($0)
        } && !service.hasPrefix("-")
    }
    private var quotedService: String { SSHConnectionManager.shellQuote(service) }

    var body: some View {
        List {
            Section {
                Picker("Panel", selection: $section) {
                    Text("Services").tag("Services")
                    Text("Docker").tag("Docker")
                    Text("Logs").tag("Logs")
                }.pickerStyle(.segmented)
                Label(server.name, systemImage: "server.rack").font(.headline)
            }.disabled(running)
            if section == "Services" || section == "Logs" {
                Section("Service name") {
                    TextField("telegrambot", text: $service)
                        .autocorrectionDisabled().textInputAutocapitalization(.never)
                    if !validService { Text("Enter a service name, not a shell command.").foregroundStyle(.red) }
                }.disabled(running)
            }
            if section == "Services" {
                Section("Inspect") {
                    Button("Service status") { execute("systemctl status --no-pager -- \(quotedService)") }.disabled(!validService || running)
                    Button("Failed services") { execute("systemctl --failed --no-pager") }.disabled(running)
                }
                Section("Actions · require server permissions") {
                    ForEach(["start", "restart", "stop"], id: \.self) { action in
                        Button(action.capitalized) { pendingAction = action }
                            .disabled(!validService || running)
                    }
                    Text("Actions request confirmation. No automatic sudo or password prompt is used.").font(.caption).foregroundStyle(.secondary)
                }
            } else if section == "Docker" {
                Section("Read-only Docker reports") {
                    Button("Containers") { execute("docker ps -a --no-trunc") }
                    Button("Resource snapshot") { execute("docker stats --no-stream") }
                    Button("Images") { execute("docker images") }
                    Button("Disk usage") { execute("docker system df") }
                }.disabled(running)
            } else {
                Section("Log snapshots") {
                    Button("Latest 100 service entries") {
                        execute("journalctl -u \(quotedService) -n 100 --no-pager -o short-iso")
                    }.disabled(!validService || running)
                    Button("System errors") { execute("journalctl -p err -n 100 --no-pager") }.disabled(running)
                    Text("Snapshots, not a streaming connection. Refresh to read new entries.").font(.caption).foregroundStyle(.secondary)
                }
            }
            if running { Section { ProgressView("Reading \(server.name)…") } }
            if !output.isEmpty { ToolOutput(text: output) }
        }.scrollContentBackground(.hidden).background(StudioBackground()).navigationTitle("Operations")
            .alert("Confirm service action", isPresented: Binding(get: { pendingAction != nil }, set: { if !$0 { pendingAction = nil } })) {
                Button("Cancel", role: .cancel) { pendingAction = nil }
                Button("Execute", role: .destructive) {
                    if let action = pendingAction, validService {
                        execute("systemctl --no-ask-password \(action) -- \(quotedService); systemctl status --no-pager -- \(quotedService)")
                    }
                    pendingAction = nil
                }
            } message: {
                Text("\(pendingAction ?? "") \(service) on \(server.name).\nStopping or restarting can interrupt users and running work.")
            }
    }
    private func execute(_ command: String) {
        guard !running else { return }
        running = true
        output = "$ \(command)\n\n"
        Task { @MainActor in
            defer { running = false }
            do { output += try await SSHConnectionManager.shared.execute(command, on: server) }
            catch { output += "\nError: \(error.localizedDescription)" }
        }
    }
}
