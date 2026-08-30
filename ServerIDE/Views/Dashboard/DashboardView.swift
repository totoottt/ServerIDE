import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var serverStore: ServerStore
    @AppStorage("appTheme") private var themeName = AppTheme.emeraldMatrix.rawValue
    private var theme: AppTheme { AppTheme(rawValue: themeName) ?? .emeraldMatrix }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                
                // Top Live Glass Badge
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(red: 0.15, green: 0.92, blue: 0.58))
                        .frame(width: 8, height: 8)
                        .shadow(color: Color(red: 0.15, green: 0.92, blue: 0.58), radius: 4)
                    Text("Command Matrix · 0.8.0")
                        .font(.caption.bold())
                    Spacer()
                    Text("2026 CYBER CORE").font(.caption2.monospaced())
                }
                .foregroundStyle(theme.accent)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(theme.accent.opacity(0.35), lineWidth: 1))

                // Hero Workspace Glass Card
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        GlassIconPod(icon: "terminal.fill", color: theme.accent, size: 44, iconSize: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SERVERIDE / STUDIO")
                                .font(.caption.bold())
                                .tracking(2)
                                .foregroundStyle(theme.accent)
                            Text("PRO ENVIRONMENT")
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    Text("Your infrastructure.\nWithin reach.")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("مساحة واحدة متكاملة لإدارة السيرفرات، الملفات، الطرفية والشبكات بتصميم زجاجي فائق.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "server.rack")
                            Text("\(serverStore.servers.count) profiles active")
                        }
                        .font(.caption.bold())
                        .foregroundStyle(theme.accent)
                        
                        Spacer()
                        
                        Text("FAST SSH")
                            .font(.caption2.monospaced().bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                            .foregroundStyle(theme.accent)
                    }
                }
                .studioSurface(glow: theme.accent)

                // Workspaces Header & Action
                HStack {
                    Text("Workspaces")
                        .font(.title2.bold())
                    Spacer()
                    NavigationLink { AddServerView() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                            Text("New Server")
                        }
                        .font(.subheadline.bold())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(theme.accent, in: Capsule())
                        .shadow(color: theme.accent.opacity(0.4), radius: 10, x: 0, y: 3)
                    }
                }

                // Servers List (Glassy Cards with Colored Badges)
                if serverStore.servers.isEmpty {
                    ContentUnavailableView(
                        "Connect your first server",
                        systemImage: "server.rack",
                        description: Text("Add an SSH profile to unlock live telemetry, scripts and remote terminals.")
                    )
                    .studioSurface()
                } else {
                    ForEach(serverStore.servers.sorted { ($0.isFavorite == true ? 0 : 1) < ($1.isFavorite == true ? 0 : 1) }) { server in
                        NavigationLink { ServerDetailView(server: server) } label: {
                            HStack(spacing: 16) {
                                GlassIconPod(
                                    icon: "server.rack",
                                    color: server.isFavorite == true ? Color(red: 1.00, green: 0.85, blue: 0.30) : theme.accent,
                                    size: 50,
                                    iconSize: 22
                                )

                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Text(server.name)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        if server.isFavorite == true {
                                            Image(systemName: "star.fill")
                                                .font(.caption)
                                                .foregroundStyle(Color(red: 1.00, green: 0.85, blue: 0.30))
                                        }
                                    }
                                    Text("\(server.username)@\(server.host)")
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    
                                    HStack(spacing: 8) {
                                        Text(server.group.uppercased())
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(theme.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                                            .foregroundStyle(theme.accent)
                                        
                                        if let lastUsed = server.lastUsed {
                                            Text(lastUsed.formatted(date: .abbreviated, time: .shortened))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }

                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.secondary)
                            }
                            .studioSurface(glow: server.isFavorite == true ? Color(red: 1.00, green: 0.85, blue: 0.30) : nil, interactive: true)
                        }
                        .buttonStyle(.plain)
                        .serverActions(server)
                    }
                }

                // Quick Launch Hub (Custom Palette Icons)
                Text("Developer desk")
                    .font(.title2.bold())
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 14)], spacing: 14) {
                    deskLink("Toolbox", "Local & network tools", "wrench.and.screwdriver", Color(red: 0.20, green: 0.82, blue: 1.00)) { ToolsView() }
                    deskLink("IP lookup", "Public address details", "network", Color(red: 0.78, green: 0.45, blue: 1.00)) { IPLookupView() }
                    deskLink("Password lab", "Generate locally", "key.horizontal", Color(red: 1.00, green: 0.65, blue: 0.15)) { PasswordLabView() }
                    deskLink("Appearance", "Themes & Glass", "paintpalette.fill", Color(red: 1.00, green: 0.35, blue: 0.55)) { SettingsView() }
                }

                HStack(spacing: 8) {
                    Image(systemName: "shield.lefthalf.filled")
                        .foregroundColor(Color(red: 0.15, green: 0.92, blue: 0.58))
                    Text("Profiles are stored in local sandbox. Keys encrypted with iOS Keychain.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
            .padding(20)
            .frame(maxWidth: 960)
            .frame(maxWidth: .infinity)
        }
        .background(StudioBackground())
        .navigationTitle("Command Center")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func deskLink<D: View>(_ title: String, _ subtitle: String, _ icon: String, _ iconColor: Color, @ViewBuilder destination: () -> D) -> some View {
        NavigationLink(destination: destination()) {
            VStack(alignment: .leading, spacing: 12) {
                GlassIconPod(icon: icon, color: iconColor, size: 42, iconSize: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).foregroundColor(.white)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
            .studioSurface(glow: iconColor, interactive: true)
        }
        .buttonStyle(.plain)
    }
}
