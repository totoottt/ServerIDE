import SwiftUI

struct SettingsView: View {
    @AppStorage("terminalTheme") private var theme = "classic"
    @AppStorage("terminalFontSize") private var fontSize = 18.0
    @AppStorage("appTheme") private var appTheme = "aurora"
    @EnvironmentObject private var store: ServerStore
    @AppStorage("terminalWrapLines") private var terminalWrap = true
    @AppStorage("fileWrapNames") private var fileWrap = true
    @AppStorage("fileFontSize") private var fileSize = 15.0

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }
    private var releaseMarker: String {
        Bundle.main.object(forInfoDictionaryKey: "ServerIDEReleaseMarker") as? String ?? "UNKNOWN-BUILD"
    }

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("App style · ستايل التطبيق", selection: $appTheme) {
                    ForEach(AppTheme.allCases) { style in
                        Text(style.title).tag(style.rawValue)
                    }
                }
                HStack(spacing: 12) {
                    ForEach(AppTheme.allCases) { style in
                        Button { appTheme = style.rawValue } label: {
                            Image(systemName: appTheme == style.rawValue ? "checkmark.circle.fill" : "circle.fill")
                                .font(.title).foregroundStyle(style.accent)
                        }.buttonStyle(.plain).accessibilityLabel(style.title)
                    }
                }
                Picker("Terminal theme", selection: $theme) {
                    Text("Classic Green").tag("classic")
                    Text("Ocean Blue").tag("ocean")
                    Text("Amber").tag("amber")
                    Text("Light Paper").tag("paper")
                }
                LabeledContent("Font size", value: "\(Int(fontSize)) pt")
                Slider(value: $fontSize, in: 14...34, step: 1)
                Toggle("Wrap terminal lines", isOn: $terminalWrap)
                LabeledContent("File text size", value: "\(Int(fileSize)) pt")
                Slider(value: $fileSize, in: 10...26, step: 1)
                Toggle("Wrap filenames", isOn: $fileWrap)
            }
            Section("Edit server profiles") {
                ForEach(store.servers) { server in
                    NavigationLink(server.name) { EditServerView(server: server) }
                }
            }
            Section("Apple Files integration") {
                NavigationLink("Apple Files status & downloads") { FilesIntegrationView() }
                NavigationLink("All saved transcripts") { RecordingsView() }
                Text("Downloaded files appear under On My iPhone → ServerIDE → Downloads. Remote server browsing inside Apple Files is not enabled; use Remote Files inside this app.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Security") {
                Label("Credentials protected by iOS Keychain", systemImage: "key.fill")
                Label("SSH host validation: development mode", systemImage: "exclamationmark.shield")
            }
            Section("Terminal & SSH") {
                LabeledContent("Default SSH port", value: "22")
                LabeledContent("SSH engine", value: "Citadel")
                LabeledContent("File transfer", value: "SSH shell commands")
            }
            Section("About") {
                LabeledContent("Product", value: "ServerIDE")
                LabeledContent("Version", value: "\(version) (\(build))")
                LabeledContent("Release", value: releaseMarker)
                Text("A private mobile command center for servers, built around secure SSH workflows.").font(.caption).foregroundStyle(.secondary)
            }
        }.scrollContentBackground(.hidden)
            .background(StudioBackground())
            .navigationTitle("Settings")
    }
}
