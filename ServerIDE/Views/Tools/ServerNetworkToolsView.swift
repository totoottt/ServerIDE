import SwiftUI

struct ServerNetworkToolsView: View {
    let server: ServerProfile
    let initialTool: String
    @State private var tool = "Ping"
    @State private var target = ""
    @State private var ports = "22,80,443,3000,5000,5678,8080,8443"
    @State private var output = ""
    @State private var busy = false
    private var validTarget: Bool {
        !target.isEmpty && target.count <= 253 && !target.hasPrefix("-") &&
        target.unicodeScalars.allSatisfy { CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-:/").contains($0) } &&
        (tool == "Network Discovery" ? target.contains("/") : !target.contains("/"))
    }
    private var portValues: [Int]? {
        let entries = ports.split(separator: ",", omittingEmptySubsequences: false)
        let values = entries.compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        guard values.count == entries.count, (1...16).contains(values.count),
              values.allSatisfy({ (1...65535).contains($0) }) else { return nil }
        return Array(Set(values)).sorted()
    }
    var body: some View {
        Form {
            Section("Tool") {
                Picker("Tool", selection: $tool) {
                    ForEach(["Ping", "Traceroute", "Port Scan", "Network Discovery", "WHOIS", "Certificate", "Domain Audit"], id: \.self) { Text($0) }
                }
                TextField(tool == "Network Discovery" ? "IPv4 subnet, for example 192.168.1.0/24" : "Target host / IP", text: $target)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                if tool == "Port Scan" {
                    TextField("Ports, comma-separated", text: $ports).keyboardType(.numbersAndPunctuation)
                }
                Button(busy ? "Running…" : "Run diagnostic") { run() }
                    .disabled(busy || !validTarget || (tool == "Port Scan" && portValues == nil))
            }.disabled(busy)
            Section {
                Text("Runs from \(server.name) over SSH, toward the target entered above — not from your iPhone. Only inspect systems you own or are authorized to manage. Discovery is limited to one IPv4 /24 (256 addresses). Port Scan accepts at most 16 explicit ports.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if busy { ProgressView() }
            if !output.isEmpty { ToolOutput(text: output) }
        }.navigationTitle("Server Tools").scrollContentBackground(.hidden).background(StudioBackground())
            .onAppear { tool = initialTool; target = server.host }
    }
    private func run() {
        guard validTarget, !busy else { return }
        let host = SSHConnectionManager.shellQuote(target)
        let command: String
        switch tool {
        case "Ping":
            command = "command -v ping >/dev/null 2>&1 && timeout 15 ping -n -c 4 -W 2 -- \(host) || printf '\\nPing unavailable or target did not reply.\\n'"
        case "Traceroute":
            command = "if command -v traceroute >/dev/null 2>&1; then timeout 25 traceroute -n -m 12 -w 1 -q 1 -- \(host); elif command -v tracepath >/dev/null 2>&1; then timeout 25 tracepath -n -- \(host); else printf 'Install traceroute or tracepath on this server to use this diagnostic.\\n'; fi"
        case "Port Scan":
            guard let values = portValues else { return }
            let script = """
            import socket,sys
            host=sys.argv[1]
            for port in [\(values.map(String.init).joined(separator: ","))]:
                try:
                    connection=socket.create_connection((host,port),timeout=1)
                    connection.close()
                    print(str(port)+' OPEN',flush=True)
                except OSError as e:
                    print(str(port)+' NOT CONNECTED: '+str(e),flush=True)
            """
            command = "timeout 25 python3 -c \(SSHConnectionManager.shellQuote(script)) \(host)"
        case "Network Discovery":
            let script = """
            import concurrent.futures,ipaddress,socket,sys
            network=ipaddress.ip_network(sys.argv[1],strict=False)
            if network.version != 4 or network.num_addresses > 256:
                raise SystemExit('Use one IPv4 /24 or smaller subnet')
            ports=(22,80,443)
            def check(ip):
                found=[]
                for port in ports:
                    try:
                        s=socket.create_connection((str(ip),port),timeout=.35);s.close();found.append(str(port))
                    except OSError: pass
                return str(ip),found
            with concurrent.futures.ThreadPoolExecutor(max_workers=48) as pool:
                for ip,found in pool.map(check,network.hosts()):
                    if found: print(ip+' OPEN '+','.join(found),flush=True)
            """
            command = "timeout 30 python3 -c \(SSHConnectionManager.shellQuote(script)) \(host)"
        case "WHOIS":
            command = "if command -v whois >/dev/null 2>&1; then timeout 20 whois -- \(host); else printf 'WHOIS is not installed. Ubuntu: sudo apt install whois\\n'; fi"
        case "Certificate":
            let inner = "printf '' | openssl s_client -connect \(target):443 -servername \(target) 2>/dev/null | openssl x509 -noout -subject -issuer -dates -serial -fingerprint -sha256"
            command = "if command -v openssl >/dev/null 2>&1; then timeout 20 sh -lc \(SSHConnectionManager.shellQuote(inner)); else printf 'OpenSSL is not installed.\\n'; fi"
        default:
            let inner = """
            printf '=== ADDRESSES ===\\n'
            getent ahosts \(host) 2>/dev/null | head -20
            if command -v dig >/dev/null 2>&1; then
              for record in A AAAA MX NS TXT; do printf '\\n=== %s ===\\n' "$record"; dig +time=3 +tries=1 +short \(host) "$record"; done
              printf '\\n=== DMARC ===\\n'; dig +time=3 +tries=1 +short "_dmarc.\(target)" TXT
            else
              printf '\\nInstall dnsutils for MX, NS, TXT and DMARC checks.\\n'
            fi
            """
            command = "timeout 25 sh -lc \(SSHConnectionManager.shellQuote(inner))"
        }
        busy = true
        output = "Origin: \(server.name)\nTarget: \(target)\n\n"
        Task { @MainActor in
            defer { busy = false }
            do {
                let result = try await SSHConnectionManager.shared.executeTerminal(command, on: server)
                output += result.output
                if result.exitCode != 0 { output += "\n[exit \(result.exitCode)]" }
            }
            catch { output += error.localizedDescription }
        }
    }
}

struct ServerToolLauncherView: View {
    let initialTool: String
    @EnvironmentObject private var store: ServerStore
    var body: some View {
        List {
            Section {
                Text("Choose the saved server that will run \(initialTool). The diagnostic originates from that Ubuntu server.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Saved servers") {
                ForEach(store.servers) { server in
                    NavigationLink {
                        ServerNetworkToolsView(server: server, initialTool: initialTool)
                    } label: {
                        Label(server.name, systemImage: "server.rack")
                    }
                }
                if store.servers.isEmpty {
                    ContentUnavailableView("No saved servers", systemImage: "server.rack",
                        description: Text("Add a server profile first."))
                }
            }
        }.navigationTitle(initialTool)
    }
}
