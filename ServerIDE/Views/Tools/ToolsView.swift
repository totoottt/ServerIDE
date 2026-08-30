import SwiftUI

struct ToolsView: View {
    @State private var search = ""
    @AppStorage("appTheme") private var themeName = "aurora"
    private var accent: Color { (AppTheme(rawValue: themeName) ?? .aurora).accent }
    private let tools = [
        ("local", "Local Terminal", "Commands in app Documents", "terminal"),
        ("github", "GitHub", "Account and repositories", "point.3.connected.trianglepath.dotted"),
        ("ip", "IP Intelligence", "Public address information", "network"),
        ("dns", "DNS Workbench", "A, AAAA, MX, TXT and more", "globe"),
        ("scanner", "Network Discovery", "Authorized IPv4 /24 from Ubuntu", "rectangle.3.group.bubble"),
        ("ports", "Port Scanner", "Check explicit TCP ports", "square.grid.3x3"),
        ("ping", "Ping", "Reachability from your server", "wave.3.right"),
        ("trace", "Traceroute", "Network path and hops", "point.topleft.down.to.point.bottomright.curvepath"),
        ("whois", "WHOIS", "Registration and allocation data", "person.text.rectangle"),
        ("certificate", "Certificate Checker", "TLS subject, issuer and expiry", "checkmark.shield"),
        ("audit", "Domain Audit", "Addresses, DNS and DMARC", "shield.lefthalf.filled"),
        ("http", "HTTP Workbench", "Methods, headers and responses", "arrow.left.arrow.right"),
        ("subnet", "Subnet Lab", "IPv4 / CIDR calculator", "point.3.connected.trianglepath.dotted"),
        ("text", "Baker / Text Lab", "Base64, URL and JSON", "curlybraces"),
        ("cron", "Cron Generator", "Build five-field schedules", "calendar.badge.clock"),
        ("hex", "Hex Viewer", "Inspect local file bytes", "number.square"),
        ("secret", "Secret Share", "Encrypt or decrypt a portable payload", "lock.doc"),
        ("password", "Password Lab", "Private on-device generation", "key.horizontal")
    ]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("THE DEVELOPER DESK").font(.caption.bold()).tracking(2).foregroundStyle(accent)
                    Text("Small tools.\nReal work.").font(.largeTitle.bold())
                    Text("أدوات تعمل بالفعل. الأدوات المحلية لا ترسل محتواك إلى الإنترنت.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).studioSurface()
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(tools.filter { search.isEmpty || ($0.1 + " " + $0.2).localizedCaseInsensitiveContains(search) }, id: \.0) { tool in
                        NavigationLink {
                            destination(tool.0)
                        } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                Image(systemName: tool.3).font(.title).foregroundStyle(accent)
                                Text(tool.1).font(.headline)
                                Text(tool.2).font(.caption).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, minHeight: 120, alignment: .leading).studioSurface()
                        }.buttonStyle(.plain)
                    }
                }
            }.padding().frame(maxWidth: 960).frame(maxWidth: .infinity)
        }.background(StudioBackground()).searchable(text: $search, prompt: "Find a tool")
            .navigationTitle("Toolbox")
    }
    @ViewBuilder private func destination(_ id: String) -> some View {
        switch id {
        case "local": LocalTerminalView()
        case "github": GitHubAccountView()
        case "ip": IPLookupView()
        case "dns": DNSWorkbenchView()
        case "scanner": ServerToolLauncherView(initialTool: "Network Discovery")
        case "ports": ServerToolLauncherView(initialTool: "Port Scan")
        case "ping": ServerToolLauncherView(initialTool: "Ping")
        case "trace": ServerToolLauncherView(initialTool: "Traceroute")
        case "whois": ServerToolLauncherView(initialTool: "WHOIS")
        case "certificate": ServerToolLauncherView(initialTool: "Certificate")
        case "audit": ServerToolLauncherView(initialTool: "Domain Audit")
        case "http": HTTPWorkbenchView()
        case "subnet": SubnetLabView()
        case "text": TextLabView()
        case "cron": CronGeneratorView()
        case "hex": HexViewerView()
        case "secret": EncryptedSecretView()
        default: PasswordLabView()
        }
    }
}
