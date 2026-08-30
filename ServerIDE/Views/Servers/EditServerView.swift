import SwiftUI

struct EditServerView: View {
    @EnvironmentObject private var serverStore: ServerStore
    @Environment(\.dismiss) private var dismiss
    @State var server: ServerProfile
    @State private var port = ""
    @State private var password = ""
    @State private var error = ""
    private var valid: Bool {
        !server.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !server.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (Int(port).map { (1...65535).contains($0) } ?? false)
    }
    var body: some View {
        Form {
            Section("Server profile") {
                TextField("Name", text: $server.name)
                TextField("Host", text: $server.host).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("Port", text: $port).keyboardType(.numberPad)
                TextField("Username", text: $server.username).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("Group", text: $server.group)
            }
            Section("Credentials") {
                LabeledContent("Authentication", value: server.authenticationType.title)
                if server.authenticationType == .password {
                    SecureField("New password (leave blank to keep)", text: $password)
                }
                Text("Existing credentials stay in Keychain. Changing a profile does not modify the server account.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Preview URL") {
                TextField("https://…", text: $server.previewURL).textInputAutocapitalization(.never).autocorrectionDisabled()
            }
            Section("Notes") { TextEditor(text: $server.notes).frame(minHeight: 120) }
            if !error.isEmpty { Text(error).foregroundStyle(.red) }
        }.navigationTitle("Edit Server").scrollContentBackground(.hidden).background(StudioBackground())
            .onAppear { port = String(server.port) }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard valid else { return }
                        if !password.isEmpty && !CredentialStore.savePassword(password, for: server.id) {
                            error = "Keychain did not save the new password. Profile was not changed."
                            return
                        }
                        server.host = server.host.trimmingCharacters(in: .whitespacesAndNewlines)
                        server.username = server.username.trimmingCharacters(in: .whitespacesAndNewlines)
                        server.port = Int(port) ?? server.port
                        serverStore.update(server)
                        dismiss()
                    }.disabled(!valid)
                }
            }
    }
}

struct ServerNotesView: View {
    @EnvironmentObject private var store: ServerStore
    @Environment(\.dismiss) private var dismiss
    let server: ServerProfile
    @State private var notes = ""
    var body: some View {
        Form {
            Section(server.name) {
                TextEditor(text: $notes).frame(minHeight: 240)
                Text("Notes are local, unencrypted profile data. Do not put passwords here.").font(.caption).foregroundStyle(.secondary)
            }
        }.navigationTitle("Notes")
            .onAppear { notes = store.servers.first(where: { $0.id == server.id })?.notes ?? server.notes }
            .toolbar {
                Button("Save") {
                    if var current = store.servers.first(where: { $0.id == server.id }) {
                        current.notes = notes
                        store.update(current)
                    }
                    dismiss()
                }
            }
    }
}
