import SwiftUI
import UIKit
import LocalAuthentication

enum ServerSheet: String, Identifiable {
    case terminal, files, edit, notes, recordings, ping, traceroute, ports
    var id: String { rawValue }
}

struct ServerActionsModifier: ViewModifier {
    let server: ServerProfile
    @EnvironmentObject private var store: ServerStore
    @State private var route: ServerSheet?
    @State private var deleteConfirmation = false
    @State private var message: String?
    private var current: ServerProfile { store.servers.first { $0.id == server.id } ?? server }

    func body(content: Content) -> some View {
        content.contextMenu {
            Button { store.markUsed(server.id); route = .terminal } label: { Label("SSH · Open or resume", systemImage: "terminal") }
            Button { route = .files } label: { Label("Remote Files", systemImage: "folder") }
            Divider()
            Button { route = .edit } label: { Label("Edit", systemImage: "pencil") }
            Button {
                if !store.clone(current) { message = "Could not copy credentials. No clone was added." }
            } label: { Label("Clone with credentials", systemImage: "square.on.square") }
            Button { route = .notes } label: { Label("Notes", systemImage: "note.text") }
            Button { route = .recordings } label: { Label("Recordings", systemImage: "record.circle") }
            Button { store.toggleFavorite(server.id) } label: {
                Label(current.isFavorite == true ? "Remove Favorite" : "Favorite", systemImage: current.isFavorite == true ? "star.slash" : "star")
            }
            Menu("Tools", systemImage: "wrench.and.screwdriver") {
                Button("Ping") { route = .ping }
                Button("Traceroute") { route = .traceroute }
                Button("Port Scan") { route = .ports }
            }
            Menu("Copy", systemImage: "doc.on.doc") {
                Button("Host") { UIPasteboard.general.string = current.host }
                Button("Username") { UIPasteboard.general.string = current.username }
                Button("Password · authenticate") { copySecret(all: false) }
                Button("Host + User + Password · authenticate") { copySecret(all: true) }
            }
            Divider()
            Button(role: .destructive) { deleteConfirmation = true } label: { Label("Delete profile", systemImage: "trash") }
        }
        .sheet(item: $route) { selected in
            NavigationStack {
                destination(selected)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Done") { route = nil } }
                    }
            }
        }
        .alert("Delete \(current.name)?", isPresented: $deleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete profile", role: .destructive) { store.delete(id: server.id) }
        } message: {
            Text("Removes this saved profile and its Keychain credentials. It does not delete server files. Saved transcripts remain until removed in Recordings.")
        }
        .alert("Server action", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { message = nil }
        } message: { Text(message ?? "") }
    }

    @ViewBuilder private func destination(_ selected: ServerSheet) -> some View {
        switch selected {
        case .terminal: TerminalTabsView(server: current)
        case .files: SFTPView(server: current)
        case .edit: EditServerView(server: current)
        case .notes: ServerNotesView(server: current)
        case .recordings: RecordingsView(server: current)
        case .ping: ServerNetworkToolsView(server: current, initialTool: "Ping")
        case .traceroute: ServerNetworkToolsView(server: current, initialTool: "Traceroute")
        case .ports: ServerNetworkToolsView(server: current, initialTool: "Port Scan")
        }
    }
    private func copySecret(all: Bool) {
        let profile = current
        Task { @MainActor in
            do {
                let context = LAContext()
                let allowed = try await context.evaluatePolicy(.deviceOwnerAuthentication,
                    localizedReason: "Copy this server password to the clipboard for 60 seconds.")
                guard allowed else { return }
                guard let password = CredentialStore.password(for: profile.id) else {
                    message = "No password is stored for this profile."
                    return
                }
                let text = all ? "Host: \(profile.host)\nUser: \(profile.username)\nPassword: \(password)" : password
                UIPasteboard.general.setItems([[UIPasteboard.typeAutomatic: text]],
                    options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(60)])
                message = "Copied locally for 60 seconds. Other apps may read it when pasted."
            } catch { message = error.localizedDescription }
        }
    }
}

extension View {
    func serverActions(_ server: ServerProfile) -> some View { modifier(ServerActionsModifier(server: server)) }
}
