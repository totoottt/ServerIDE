import SwiftUI

struct HTTPWorkbenchView: View {
    @State private var address = "https://example.com"
    @State private var method = "GET"
    @State private var bodyText = ""
    @State private var output = ""
    @State private var isRunning = false
    @State private var confirmSend = false
    @State private var task: Task<Void, Never>?
    var body: some View {
        Form {
            Section("Request") {
                TextField("https://host/path", text: $address)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                Picker("Method", selection: $method) {
                    ForEach(["GET", "HEAD", "POST", "PUT", "PATCH", "DELETE"], id: \.self) { Text($0) }
                }
                if method != "GET" && method != "HEAD" {
                    Text("JSON body").font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $bodyText).frame(minHeight: 100)
                        .font(.system(.body, design: .monospaced))
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                Button {
                    if method == "GET" || method == "HEAD" { send() } else { confirmSend = true }
                } label: { Label(isRunning ? "Sending…" : "Send request", systemImage: "paperplane") }
                    .disabled(isRunning || address.isEmpty)
            }.disabled(isRunning)
            Section {
                Text("Requests use your device network, not an SSH tunnel. No request history is saved. Response preview is limited to 256 KiB. TLS certificate validation remains enabled.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if isRunning { ProgressView() }
            if !output.isEmpty { ToolOutput(text: output) }
        }.scrollContentBackground(.hidden).background(StudioBackground()).navigationTitle("HTTP Workbench")
            .confirmationDialog("Send \(method) request?", isPresented: $confirmSend, titleVisibility: .visible) {
                Button("Send to this URL", role: .destructive) { send() }
                Button("Cancel", role: .cancel) {}
            } message: { Text("\(address)\nThis request may modify or delete remote data.") }
            .onDisappear { task?.cancel() }
    }

    private func send() {
        let url = address
        let verb = method
        let body = bodyText
        isRunning = true
        output = ""
        task = Task { @MainActor in
            defer { isRunning = false }
            do {
                let response = try await NetworkTools.inspect(url: url, method: verb, body: body)
                try Task.checkCancellation()
                output = "HTTP \(response.status) · \(String(format: "%.2f", response.elapsed)) s\n\(response.finalURL)\n\n\(response.headers)\n\n\(response.body)"
                if response.truncated { output += "\n\n[Preview truncated at 256 KiB]" }
            } catch {
                if !Task.isCancelled { output = error.localizedDescription }
            }
        }
    }
}

struct DNSWorkbenchView: View {
    @State private var host = "example.com"
    @State private var type = "A"
    @State private var output = ""
    @State private var busy = false
    @State private var task: Task<Void, Never>?
    var body: some View {
        Form {
            Section("DNS records") {
                TextField("Domain", text: $host).keyboardType(.URL)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Picker("Record", selection: $type) {
                    ForEach(["A", "AAAA", "MX", "TXT", "NS", "CNAME", "SOA"], id: \.self) { Text($0) }
                }
                Button("Resolve") { resolve() }.disabled(busy || host.isEmpty)
            }.disabled(busy)
            Section {
                Text("Queries are sent over HTTPS to Google Public DNS. Results are public-resolver answers, not your server's DNS configuration.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if busy { ProgressView() }
            if !output.isEmpty { ToolOutput(text: output) }
        }.scrollContentBackground(.hidden).background(StudioBackground()).navigationTitle("DNS Workbench")
            .onDisappear { task?.cancel() }
    }
    private func resolve() {
        let name = host
        let record = type
        busy = true
        output = ""
        task = Task { @MainActor in
            defer { busy = false }
            do {
                let result = try await NetworkTools.dns(host: name, type: record)
                try Task.checkCancellation()
                output = result
            } catch { if !Task.isCancelled { output = error.localizedDescription } }
        }
    }
}
