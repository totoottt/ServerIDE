import SwiftUI

@main
struct ServerIDEApp: App {
    @StateObject private var serverStore = ServerStore()
    @AppStorage("appTheme") private var storedTheme = "midnight"
    @State private var filesError: String?
    private var theme: AppTheme { AppTheme(rawValue: storedTheme) ?? .midnight }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(serverStore)
                .tint(theme.accent)
                .preferredColorScheme(theme.scheme)
                .task {
                    do { try LocalFilesStore.prepare() }
                    catch { filesError = error.localizedDescription }
                }
                .alert("Local Files setup failed", isPresented: Binding(
                    get: { filesError != nil }, set: { if !$0 { filesError = nil } }
                )) { Button("OK") { filesError = nil } } message: { Text(filesError ?? "") }
        }
    }
}
