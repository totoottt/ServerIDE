import SwiftUI

@MainActor
final class TerminalWorkspace: ObservableObject {
    static let shared = TerminalWorkspace()
    struct Session: Identifiable {
        let id = UUID()
        let model: TerminalViewModel
    }
    @Published var sessions: [Session] = []
    @Published var selected: UUID?
    func open(_ server: ServerProfile) {
        let session = Session(model: TerminalViewModel(server: server))
        sessions.append(session)
        selected = session.id
    }
    func resumeOrOpen(_ server: ServerProfile) {
        if let existing = sessions.last(where: { $0.model.server.id == server.id }) { selected = existing.id }
        else { open(server) }
    }
    func close(_ id: UUID) {
        guard let item = sessions.first(where: { $0.id == id }), !item.model.isRunning else { return }
        sessions.removeAll { $0.id == id }
        if selected == id { selected = sessions.last?.id }
    }
}

struct TerminalTabsView: View {
    let server: ServerProfile?
    @EnvironmentObject private var store: ServerStore
    @StateObject private var workspace = TerminalWorkspace.shared
    @State private var opened = false
    @State private var closing: UUID?
    init(server: ServerProfile? = nil) { self.server = server }
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(workspace.sessions) { session in
                        Button {
                            workspace.selected = session.id
                        } label: {
                            Label(session.model.server.name, systemImage: "terminal")
                                .font(.caption.bold()).padding(10)
                                .background(workspace.selected == session.id ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.08),
                                            in: Capsule())
                        }.buttonStyle(.plain)
                            .contextMenu { Button("Close tab", role: .destructive) { closing = session.id } }
                    }
                    Menu {
                        ForEach(store.servers) { profile in
                            Button(profile.name) { workspace.open(profile) }
                        }
                        if store.servers.isEmpty { Text("Add a server first") }
                    } label: { Image(systemName: "plus.circle.fill").font(.title2) }
                    .accessibilityLabel("New SSH command tab")
                }.padding(10)
            }
            if let session = workspace.sessions.first(where: { $0.id == workspace.selected }) {
                TerminalView(model: session.model).id(session.id)
            } else {
                ContentUnavailableView("No open tabs", systemImage: "terminal",
                    description: Text("Use + to open a command workspace."))
            }
        }
        .navigationTitle("Terminal (\(workspace.sessions.count))")
        .toolbar {
            if let id = workspace.selected {
                Button("Close tab", systemImage: "xmark.circle") { closing = id }
            }
        }
        .onAppear {
            if !opened {
                if let server { workspace.resumeOrOpen(server) }
                opened = true
            }
        }
        .alert("Close this tab?", isPresented: Binding(get: { closing != nil }, set: { if !$0 { closing = nil } })) {
            Button("Cancel", role: .cancel) { closing = nil }
            Button("Close", role: .destructive) {
                if let id = closing { workspace.close(id) }
                closing = nil
            }
        } message: {
            Text("Unsaved output will be discarded. A tab with a running command cannot be closed. Tabs stay available until closed or the app exits.")
        }
    }
}
