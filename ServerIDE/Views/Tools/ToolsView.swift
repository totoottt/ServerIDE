import SwiftUI

struct ToolMeta: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
}

struct ToolsView: View {
    @State private var search = ""
    @AppStorage("appTheme") private var themeName = AppTheme.emeraldMatrix.rawValue
    private var theme: AppTheme { AppTheme(rawValue: themeName) ?? .emeraldMatrix }

    // تعريف الأدوات مع تخصيص لوني مدروس وجمالي لكل أداة
    private let tools: [ToolMeta] = [
        ToolMeta(id: "local",       title: "Local Terminal",    subtitle: "Python, Shell & Docs",            icon: "terminal.fill",                                     color: Color(red: 0.15, green: 0.92, blue: 0.58)), // Cyber Green
        ToolMeta(id: "github",      title: "GitHub",            subtitle: "Repos & commits",                 icon: "point.3.connected.trianglepath.dotted",             color: Color(red: 0.85, green: 0.40, blue: 1.00)), // Purple
        ToolMeta(id: "ip",          title: "IP Intelligence",   subtitle: "Public address & ASN",            icon: "network",                                           color: Color(red: 0.20, green: 0.82, blue: 1.00)), // Cyan
        ToolMeta(id: "dns",         title: "DNS Workbench",     subtitle: "A, AAAA, MX, TXT records",        icon: "globe.americas.fill",                               color: Color(red: 0.35, green: 0.65, blue: 1.00)), // Electric Blue
        ToolMeta(id: "scanner",     title: "Network Discovery", subtitle: "Live subnet exploration",         icon: "rectangle.3.group.bubble.fill",                     color: Color(red: 0.15, green: 0.88, blue: 0.82)), // Teal
        ToolMeta(id: "ports",       title: "Port Scanner",      subtitle: "Open TCP/UDP listening ports",    icon: "square.grid.3x3.fill",                              color: Color(red: 1.00, green: 0.55, blue: 0.15)), // Amber
        ToolMeta(id: "ping",        title: "Ping Latency",      subtitle: "ICMP latency & packet drop",      icon: "wave.3.right",                                      color: Color(red: 0.25, green: 0.90, blue: 0.65)), // Mint
        ToolMeta(id: "trace",       title: "Traceroute",        subtitle: "Network routing hops",            icon: "point.topleft.down.to.point.bottomright.curvepath", color: Color(red: 0.95, green: 0.35, blue: 0.60)), // Rose
        ToolMeta(id: "whois",       title: "WHOIS Registry",    subtitle: "Registrar & IP owner",            icon: "person.text.rectangle.fill",                        color: Color(red: 1.00, green: 0.78, blue: 0.20)), // Gold
        ToolMeta(id: "certificate", title: "TLS / SSL Check",   subtitle: "Certificate chain & expiry",      icon: "lock.shield.fill",                                  color: Color(red: 0.15, green: 0.92, blue: 0.58)), // Emerald
        ToolMeta(id: "audit",       title: "Domain Audit",      subtitle: "SPF, DKIM, DMARC checks",         icon: "shield.checkered",                                  color: Color(red: 0.20, green: 0.82, blue: 1.00)), // Cyan
        ToolMeta(id: "http",        title: "HTTP Workbench",    subtitle: "REST API & response headers",     icon: "arrow.left.arrow.right",                            color: Color(red: 1.00, green: 0.40, blue: 0.45)), // Crimson
        ToolMeta(id: "subnet",      title: "Subnet Lab",        subtitle: "CIDR masks & net boundaries",     icon: "circle.grid.cross.fill",                            color: Color(red: 0.65, green: 0.50, blue: 1.00)), // Lavender
        ToolMeta(id: "text",        title: "Baker / Text Lab",  subtitle: "Base64, URL & JSON parser",       icon: "curlybraces",                                       color: Color(red: 1.00, green: 0.75, blue: 0.20)), // Yellow
        ToolMeta(id: "cron",        title: "Cron Generator",    subtitle: "Schedule syntax builder",         icon: "calendar.badge.clock",                              color: Color(red: 0.40, green: 0.80, blue: 0.95)), // Sky
        ToolMeta(id: "hex",         title: "Hex Viewer",        subtitle: "Binary bytes analyzer",           icon: "number.square.fill",                                color: Color(red: 0.70, green: 0.75, blue: 0.85)), // Titanium
        ToolMeta(id: "secret",      title: "Secret Share",      subtitle: "AES-256 payload encryption",      icon: "lock.doc.fill",                                     color: Color(red: 1.00, green: 0.30, blue: 0.35)), // Red
        ToolMeta(id: "password",    title: "Password Lab",      subtitle: "High-entropy random keys",        icon: "key.horizontal.fill",                               color: Color(red: 1.00, green: 0.65, blue: 0.15))  // Orange
    ]

    var filteredTools: [ToolMeta] {
        if search.trimmingCharacters(in: .whitespaces).isEmpty {
            return tools
        }
        return tools.filter {
            $0.title.localizedCaseInsensitiveContains(search) ||
            $0.subtitle.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                // Hero Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        GlassIconPod(icon: "wrench.and.screwdriver.fill", color: theme.accent, size: 40, iconSize: 18)
                        Text("DEVELOPER TOOLBOX")
                            .font(.caption.bold())
                            .tracking(2)
                            .foregroundStyle(theme.accent)
                    }
                    
                    Text("Supercharged Tools.\nZero Latency.")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("أدوات شبكية ومحلية متقدمة تعمل بكفاءة تامة وتصميم زجاجي نابض بالألوان.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .studioSurface(glow: theme.accent)

                // Grid of Glass Tools
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 14)], spacing: 14) {
                    ForEach(filteredTools) { tool in
                        NavigationLink {
                            destination(tool.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                GlassIconPod(icon: tool.icon, color: tool.color, size: 44, iconSize: 20)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(tool.title)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text(tool.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 125, alignment: .topLeading)
                            .studioSurface(glow: tool.color, interactive: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 960)
            .frame(maxWidth: .infinity)
        }
        .background(StudioBackground())
        .searchable(text: $search, prompt: "Search network & developer tools...")
        .navigationTitle("Toolbox")
    }

    @ViewBuilder
    private func destination(_ id: String) -> some View {
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
