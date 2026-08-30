import SwiftUI
import CryptoKit

struct RemoteCodeEditorView: View {
    let server: ServerProfile
    let file: RemoteFile

    @State private var text = ""
    @State private var originalText = ""
    @State private var originalHash = ""
    @State private var loadedSuccessfully = false
    @State private var isRunning = false
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var output = ""
    @State private var errorMessage: String?
    @AppStorage("editorFontSize") private var fontSize = 14.0

    private var hasChanges: Bool {
        text != originalText
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                Spacer()
                ProgressView("Opening \(file.name)…")
                Spacer()
            } else {
                TextEditor(text: $text)
                    .font(.system(size: fontSize, design: .monospaced))
                    .disabled(isSaving || isRunning || !loadedSuccessfully)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                if !output.isEmpty {
                    Divider()
                    ScrollView {
                        Text(output)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 180)
                    .background(Color.black)
                    .foregroundStyle(Color.green)
                }
            }
        }
        .navigationTitle(file.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button("Smaller text") { fontSize = max(10, fontSize - 1) }
                    Button("Larger text") { fontSize = min(30, fontSize + 1) }
                } label: { Image(systemName: "textformat.size") }
                Button {
                    save()
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
                .disabled(!hasChanges || isSaving || isRunning || !loadedSuccessfully)

                Button {
                    runRemoteFile()
                } label: {
                    Image(systemName: "play.fill")
                }
                .disabled(isLoading || isSaving || isRunning || !loadedSuccessfully)
            }
        }
        .task {
            await load()
        }
        .alert("Editor Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func load() async {
        do {
            let reply = try await RemoteFileBridge.call(["op": "read", "path": file.path], server: server)
            guard let encoded = reply.data, let data = Data(base64Encoded: encoded),
                  let contents = String(data: data, encoding: .utf8), let hash = reply.sha256 else {
                throw SSHConnectionError.invalidTextEncoding
            }
            text = contents
            originalText = contents
            originalHash = hash
            loadedSuccessfully = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func save() {
        guard !isSaving, !isRunning, loadedSuccessfully else { return }
        isSaving = true
        Task {
            do {
                try await saveDraft()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }

    @MainActor private func saveDraft() async throws {
        let snapshot = text
        let backup = try await RemoteFileBridge.saveText(snapshot, destination: file.path, expectedSHA256: originalHash, server: server)
        originalText = snapshot
        originalHash = SHA256.hash(data: Data(snapshot.utf8)).map { String(format: "%02x", $0) }.joined()
        output = "Saved successfully. Backup: \(backup)"
    }

    private func runRemoteFile() {
        guard !isRunning, !isSaving, loadedSuccessfully else { return }
        isRunning = true
        Task {
            defer { isRunning = false }
            do {
                // Save first so Run always executes the latest editor contents.
                if hasChanges {
                    try await saveDraft()
                }

                let ext = (file.name as NSString).pathExtension.lowercased()
                let quoted = shellQuote(file.path)

                let command: String
                switch ext {
                case "py":
                    command = "python3 \(quoted)"
                case "sh":
                    command = "bash \(quoted)"
                case "js":
                    command = "node \(quoted)"
                case "php":
                    command = "php \(quoted)"
                default:
                    command = "chmod +x \(quoted) && \(quoted)"
                }

                output = "$ \(command)\n"
                // A script returning exit code 1 is useful program output, not an
                // editor failure. Preserve stderr and report the exit code instead
                // of showing Citadel's generic CommandFailed alert.
                let result = try await SSHConnectionManager.shared.executeTerminal(command, on: server)
                output += result.output
                if result.exitCode != 0 {
                    output += "\n\nProcess finished with exit code \(result.exitCode)."
                }
            } catch {
                output += "\nError: \(error.localizedDescription)"
                errorMessage = error.localizedDescription
            }
        }
    }

    private func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
