import SwiftUI

struct FilesIntegrationView: View {
    @State private var message = ""
    @State private var files: [URL] = []
    private func flag(_ key: String) -> Bool { Bundle.main.object(forInfoDictionaryKey: key) as? Bool == true }
    var body: some View {
        List {
            Section("Installed build configuration") {
                Label("File sharing", systemImage: flag("UIFileSharingEnabled") ? "checkmark.circle.fill" : "xmark.circle")
                Label("Open documents in place", systemImage: flag("LSSupportsOpeningDocumentsInPlace") ? "checkmark.circle.fill" : "xmark.circle")
                Text("Files → Browse → On My iPhone → ServerIDE → Downloads")
                    .font(.body.weight(.semibold)).textSelection(.enabled)
                Text("This folder stores local downloads. It does not mount your SSH server in Apple Files.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Local downloads") {
                Button("Prepare folder and refresh", systemImage: "arrow.clockwise") { refresh() }
                ForEach(files, id: \.path) { url in
                    ShareLink(item: url) { Label(url.lastPathComponent, systemImage: "doc") }
                }
                if !message.isEmpty { Text(message).font(.caption) }
            }
        }
        .navigationTitle("Apple Files")
        .task { refresh() }
    }
    private func refresh() {
        do {
            try LocalFilesStore.prepare()
            files = try FileManager.default.contentsOfDirectory(at: LocalFilesStore.downloads(), includingPropertiesForKeys: nil)
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            message = "Local folder is ready."
        } catch { message = error.localizedDescription }
    }
}
