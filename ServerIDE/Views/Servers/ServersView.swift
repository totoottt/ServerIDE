import SwiftUI

struct ServersView: View {
    @EnvironmentObject var serverStore: ServerStore

    var body: some View {
        List {
            if serverStore.servers.isEmpty {
                ContentUnavailableView(
                    "No Servers",
                    systemImage: "server.rack",
                    description: Text("Add your first SSH server.")
                )
            } else {
                ForEach(serverStore.servers) { server in
                    NavigationLink(value: server) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(server.name).font(.headline)
                            Text("\(server.username)@\(server.host):\(server.port)")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }.serverActions(server)
                }
            }
        }
        .navigationTitle("Servers")
        .scrollContentBackground(.hidden)
        .background(StudioBackground())
        .toolbar {
            NavigationLink {
                AddServerView()
            } label: {
                Image(systemName: "plus")
            }
        }
        .navigationDestination(for: ServerProfile.self) { server in
            ServerDetailView(server: server)
        }
    }
}
