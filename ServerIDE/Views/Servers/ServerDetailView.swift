import SwiftUI

struct ServerDetailView: View {
    let server: ServerProfile
    @EnvironmentObject private var serverStore: ServerStore

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                hero
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    WorkspaceTile(title: "Terminal", subtitle: "Multiple command tabs", icon: "terminal") { TerminalTabsView(server: server) }
                    WorkspaceTile(title: "Files", subtitle: "Browse over SSH", icon: "folder") { SFTPView(server: server) }
                    WorkspaceTile(title: "Metrics", subtitle: "Server resource snapshot", icon: "chart.xyaxis.line") { ServerMetricsView(server: server) }
                    WorkspaceTile(title: "Operations", subtitle: "Services, Docker & logs", icon: "slider.horizontal.3") { ServerOperationsView(server: server) }
                    WorkspaceTile(title: "Command Vault", subtitle: "Useful server commands", icon: "tray.full") { SnippetsView(server: server) }
                    if !server.previewURL.isEmpty {
                        WorkspaceTile(title: "Web Preview", subtitle: "Open hosted service", icon: "safari") { WebPreviewView(initialURL: server.previewURL) }
                    }
                }
                connection
            }.padding()
        }
        .navigationTitle(server.name)
        .background(StudioBackground())
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { serverStore.markUsed(server.id) }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack { RoundedRectangle(cornerRadius: 18).fill(Color.accentColor.opacity(0.12)); Image(systemName: "server.rack").font(.system(size: 30)).foregroundStyle(Color.accentColor) }.frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 4) { Text(server.name).font(.title2.bold()); Text("\(server.username)@\(server.host):\(server.port)").font(.caption.monospaced()).foregroundStyle(.secondary) }
                Spacer()
            }
            HStack { Label(server.group, systemImage: "folder"); Spacer(); Label(server.authenticationType.title, systemImage: "lock.shield") }.font(.caption).foregroundStyle(.secondary)
        }.padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    private var connection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connection").font(.headline)
            LabeledContent("Host", value: server.host)
            LabeledContent("Port", value: "\(server.port)")
            LabeledContent("User", value: server.username)
            LabeledContent("Authentication", value: server.authenticationType.title)
        }.padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct WorkspaceTile<Destination: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let destination: Destination

    init(title: String, subtitle: String, icon: String, @ViewBuilder destination: () -> Destination) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.destination = destination()
    }

    var body: some View {
        NavigationLink(destination: destination) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon).font(.title2).foregroundStyle(Color.accentColor)
                Text(title).font(.headline).foregroundStyle(.primary)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
            }.frame(maxWidth: .infinity, minHeight: 105, alignment: .leading).padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
    }
}
