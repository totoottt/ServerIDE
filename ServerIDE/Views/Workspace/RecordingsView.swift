import SwiftUI
import CryptoKit

struct TerminalTranscript: Codable, Identifiable {
    var id = UUID()
    let serverID: UUID
    let serverName: String
    let created: Date
    let text: String
}

@MainActor
final class TranscriptStore {
    static let shared = TranscriptStore()
    private let keyService = "ServerIDE.Transcripts.Key"
    private func key(create: Bool) throws -> SymmetricKey {
        if let data = KeychainService.read(service: keyService, account: "v1") {
            return SymmetricKey(data: data)
        }
        guard create else { throw CocoaError(.fileReadNoPermission) }
        let existing = try FileManager.default.contentsOfDirectory(at: directory(), includingPropertiesForKeys: nil)
        guard !existing.contains(where: { $0.pathExtension == "sealed" }) else {
            throw RemoteFileFailure(message: "Transcript key is unavailable. Existing recordings were not changed.")
        }
        let key = SymmetricKey(size: .bits256)
        let data = key.withUnsafeBytes { Data($0) }
        guard KeychainService.save(data, service: keyService, account: "v1") else { throw CocoaError(.fileWriteNoPermission) }
        return key
    }
    private func directory() throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        var url = base.appendingPathComponent("Transcripts", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
        return url
    }
    func save(server: ServerProfile, text: String) throws {
        let entry = TerminalTranscript(serverID: server.id, serverName: server.name, created: Date(), text: text)
        let sealed = try AES.GCM.seal(JSONEncoder().encode(entry), using: key(create: true))
        guard let data = sealed.combined else { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: directory().appendingPathComponent(entry.id.uuidString + ".sealed"),
                       options: [.atomic, .completeFileProtection])
    }
    func list(serverID: UUID? = nil) throws -> [TerminalTranscript] {
        let urls = try FileManager.default.contentsOfDirectory(at: directory(), includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "sealed" }
        guard !urls.isEmpty else { return [] }
        let encryptionKey = try key(create: false)
        return try urls.map { url in
            let plaintext = try AES.GCM.open(AES.GCM.SealedBox(combined: Data(contentsOf: url)), using: encryptionKey)
            return try JSONDecoder().decode(TerminalTranscript.self, from: plaintext)
        }.filter { serverID == nil || $0.serverID == serverID }.sorted { $0.created > $1.created }
    }
    func delete(_ id: UUID) throws {
        try FileManager.default.removeItem(at: directory().appendingPathComponent(id.uuidString + ".sealed"))
    }
}

struct RecordingsView: View {
    let server: ServerProfile?
    init(server: ServerProfile? = nil) { self.server = server }
    @State private var entries: [TerminalTranscript] = []
    @State private var error: String?
    @State private var deleting: TerminalTranscript?
    var body: some View {
        List {
            Section {
                Text("Encrypted text snapshots saved explicitly from Terminal. Stored on this device; not in the public Files folder.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(entries) { entry in
                NavigationLink {
                    ScrollView { Text(entry.text).font(.system(.callout, design: .monospaced)).textSelection(.enabled).padding() }
                        .navigationTitle("Transcript")
                } label: {
                    VStack(alignment: .leading) {
                        Text(entry.serverName)
                        Text(entry.created.formatted()).font(.caption).foregroundStyle(.secondary)
                    }
                }.swipeActions { Button("Delete", role: .destructive) { deleting = entry } }
            }
            if entries.isEmpty { Text("No saved transcripts for this server.") }
            if let error { Text(error).foregroundStyle(.red) }
        }.navigationTitle("Recordings").onAppear { reload() }
            .alert("Delete this transcript?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
                Button("Cancel", role: .cancel) { deleting = nil }
                Button("Delete", role: .destructive) {
                    do {
                        if let entry = deleting { try TranscriptStore.shared.delete(entry.id) }
                        reload()
                    } catch { self.error = error.localizedDescription }
                    deleting = nil
                }
            } message: { Text("This cannot be undone. The server is not affected.") }
    }
    private func reload() {
        do { entries = try TranscriptStore.shared.list(serverID: server?.id); error = nil }
        catch { self.error = error.localizedDescription }
    }
}
