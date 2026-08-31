import SwiftUI

struct AddServerView: View {
    @EnvironmentObject var serverStore: ServerStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var host = ""
    @State private var port = "22"
    @State private var username = "root"
    @State private var authenticationType: SSHAuthenticationType = .password
    @State private var password = ""
    @State private var privateKey = ""
    @State private var passphrase = ""
    @State private var previewURL = ""

    var body: some View {
        Form {
            Section("Server") {
                TextField("Name", text: $name)
                TextField("Host / IP", text: $host)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Port", text: $port).keyboardType(.numberPad)
                TextField("Username", text: $username)
                    .textInputAutocapitalization(.never)
            }

            Section("Authentication") {
                Picker("Method", selection: $authenticationType) {
                    ForEach(SSHAuthenticationType.allCases) { method in
                        Text(method.title).tag(method)
                    }
                }

                if authenticationType == .password {
                    SecureField("Password", text: $password)
                } else {
                    TextEditor(text: $privateKey)
                        .frame(minHeight: 140)
                        .font(.system(size: 12, design: .monospaced))
                    SecureField("Passphrase (optional)", text: $passphrase)
                    Text("Private key is stored in iOS Keychain. Authentication wiring follows after the first cloud compile.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Web Preview") {
                TextField("https://example.com or http://host:5000", text: $previewURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
            }

            Button("Save Server") {
                let server = ServerProfile(
                    name: name.isEmpty ? host : name,
                    host: host,
                    port: Int(port) ?? 22,
                    username: username,
                    authenticationType: authenticationType,
                    previewURL: previewURL
                )
                serverStore.add(server)
                if authenticationType == .password {
                    if !password.isEmpty { CredentialStore.savePassword(password, for: server.id) }
                } else if !privateKey.isEmpty {
                    CredentialStore.savePrivateKey(privateKey, passphrase: passphrase, for: server.id)
                }
                dismiss()
            }
            .disabled(host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .navigationTitle("Add Server")
    }
}
