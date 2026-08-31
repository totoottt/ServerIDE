import SwiftUI

@main
struct ServerIDEApp: App {
    @StateObject private var serverStore = ServerStore()
    @AppStorage("appTheme") private var storedTheme = "aurora"
    @State private var filesError: String?
    private var theme: AppTheme { AppTheme(rawValue: storedTheme) ?? .aurora }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(serverStore)
                .tint(theme.accent)
                .preferredColorScheme(theme.scheme)
                .task {
                    do {
                        try LocalFilesStore.prepare()
                        DownloadManager.shared.resumePending()
                    }
                    catch { filesError = error.localizedDescription }
                }
                .alert("Local Files setup failed", isPresented: Binding(
                    get: { filesError != nil }, set: { if !$0 { filesError = nil } }
                )) { Button("OK") { filesError = nil } } message: { Text(filesError ?? "") }
        }
    }
}
