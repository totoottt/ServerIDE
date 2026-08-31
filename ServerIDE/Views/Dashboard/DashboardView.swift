import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var serverStore: ServerStore
    @AppStorage("appTheme") private var themeName = "aurora"
    private var theme: AppTheme { AppTheme(rawValue: themeName) ?? .aurora }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                    Text("Project tools · 0.7.1 (12)")
                    Spacer()
                    Text("29 AUG 2026").font(.caption2.monospaced())
                }
                .font(.caption.bold())
                .foregroundStyle(theme.accent)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(theme.accent.opacity(0.12), in: Capsule())

                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Label("SERVERIDE / STUDIO", systemImage: "square.stack.3d.up.fill")
                            .font(.caption.bold()).tracking(2).foregroundStyle(theme.accent)
                        Spacer()
                        Image(systemName: "terminal.fill").font(.title)
                    }
                    Text("Your infrastructure.\nWithin reach.")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("مساحة واحدة للسيرفر، الملفات، الأوامر وأدوات المطوّر.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    HStack {
                        Label("\(serverStore.servers.count) profiles", systemImage: "server.rack")
                        Spacer()
                        Text("SSH WORKSPACE").font(.caption2.monospaced())
                    }.font(.caption).foregroundStyle(theme.accent)
                }.studioSurface()

                HStack {
                    Text("Workspaces").font(.title2.bold())
                    Spacer()
                    NavigationLink { AddServerView() } label: {
                        Label("New", systemImage: "plus").font(.subheadline.bold())
                    }
                }
                if serverStore.servers.isEmpty {
                    ContentUnavailableView("Connect your first server", systemImage: "server.rack",
                        description: Text("Add an SSH profile to open files, commands and server metrics."))
                        .studioSurface()
                } else {
                    ForEach(serverStore.servers.sorted { ($0.isFavorite == true ? 0 : 1) < ($1.isFavorite == true ? 0 : 1) }) { server in
                        NavigationLink { ServerDetailView(server: server) } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "server.rack").font(.title2)
                                    .foregroundStyle(theme.accent)
                                    .frame(width: 48, height: 48)
                                    .background(theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack { Text(server.name).font(.headline); if server.isFavorite == true { Image(systemName: "star.fill").font(.caption) } }
                                    Text("\(server.username)@\(server.host)").font(.caption.monospaced())
                                        .foregroundStyle(.secondary).lineLimit(1)
                                    Text(server.group.uppercased()).font(.caption2.bold()).foregroundStyle(theme.accent)
                                    if let lastUsed = server.lastUsed {
                                        Text("Last opened: \(lastUsed.formatted(date: .abbreviated, time: .shortened))").font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right").foregroundStyle(theme.accent)
                            }.studioSurface()
                        }.buttonStyle(.plain).serverActions(server)
                    }
                }
                Text("Developer desk").font(.title2.bold())
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    deskLink("Toolbox", "Local & network tools", "wrench.and.screwdriver") { ToolsView() }
                    deskLink("IP lookup", "Public address details", "network") { IPLookupView() }
                    deskLink("Password lab", "Generate locally", "key.horizontal") { PasswordLabView() }
                    deskLink("Appearance", "Make it yours", "paintpalette") { SettingsView() }
                }
                Label("Profiles are saved locally. Passwords use Keychain.", systemImage: "lock")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(20).frame(maxWidth: 960).frame(maxWidth: .infinity)
        }.background(StudioBackground())
            .navigationTitle("Command Center").navigationBarTitleDisplayMode(.inline)
    }

    private func deskLink<D: View>(_ title: String, _ subtitle: String, _ icon: String,
                                    @ViewBuilder destination: () -> D) -> some View {
        NavigationLink(destination: destination()) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon).font(.title2).foregroundStyle(theme.accent)
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, minHeight: 95, alignment: .leading).studioSurface()
        }.buttonStyle(.plain)
    }
}
