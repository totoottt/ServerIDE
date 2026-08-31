import SwiftUI

struct RootView: View {
    @StateObject private var workspace = TerminalWorkspace.shared
    var body: some View {
        TabView {
            NavigationStack { DashboardView() }
                .tabItem { Label("Dashboard", systemImage: "square.grid.2x2") }

            NavigationStack { ServersView() }
                .tabItem { Label("Servers", systemImage: "server.rack") }

            NavigationStack { TerminalTabsView() }
                .tabItem { Label("Terminal", systemImage: "terminal") }
                .badge(workspace.sessions.count)

            NavigationStack { ToolsView() }
                .tabItem { Label("Tools", systemImage: "wrench.and.screwdriver") }

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
