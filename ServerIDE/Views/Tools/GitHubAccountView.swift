import SwiftUI

private struct GitHubUser: Decodable { let login: String }
private struct GitHubRepository: Decodable, Identifiable {
    let id: Int
    let full_name: String
    let html_url: URL
    let clone_url: String
}

struct GitHubAccountView: View {
    @State private var token = ""
    @State private var login: String?
    @State private var repositories: [GitHubRepository] = []
    @State private var busy = false
    @State private var message = ""
    @State private var page = 1
    @State private var hasMore = false
    private let service = "ServerIDE.GitHub"
    private var savedToken: String? {
        KeychainService.read(service: service, account: "token").flatMap { String(data: $0, encoding: .utf8) }
    }

    var body: some View {
        List {
            Section("GitHub account") {
                if let login {
                    Label(login, systemImage: "checkmark.shield.fill")
                    Button("Disconnect", role: .destructive) {
                        KeychainService.delete(service: service, account: "token")
                        self.login = nil; repositories = []; token = ""; message = ""
                    }.disabled(busy)
                } else {
                    SecureField("Fine-grained personal access token", text: $token)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Verify and save securely") { connect(token) }.disabled(busy || token.isEmpty)
                    if savedToken != nil { Button("Reconnect saved account") { connect(savedToken ?? "") }.disabled(busy) }
                    Link("Create a limited-access token on GitHub", destination: URL(string: "https://github.com/settings/personal-access-tokens/new")!)
                    Text("The token is sent only to api.github.com and saved in this device's Keychain after verification. Select only the repositories you need. This screen lists repositories and opens them in your browser; it does not clone or push code.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if login != nil {
                Section("Repositories") {
                    ForEach(repositories) { repo in
                        VStack(alignment: .leading, spacing: 6) {
                            if repo.html_url.scheme == "https", repo.html_url.host == "github.com" {
                                Link(repo.full_name, destination: repo.html_url).font(.headline)
                            } else { Text(repo.full_name).font(.headline) }
                            Text(repo.clone_url).font(.caption.monospaced()).textSelection(.enabled)
                        }
                    }
                    if hasMore { Button("Load more") { loadMore() }.disabled(busy) }
                }
            }
            if busy { ProgressView() }
            if !message.isEmpty { Section { Text(message).font(.caption) } }
        }
        .navigationTitle("GitHub")
    }

    private func connect(_ input: String) {
        let credential = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !busy, !credential.isEmpty else { return }
        busy = true; message = ""
        Task {
            defer { busy = false }
            do {
                let user: GitHubUser = try await get("user", token: credential)
                guard KeychainService.save(Data(credential.utf8), service: service, account: "token") else {
                    throw RemoteFileFailure(message: "Keychain could not save the token.")
                }
                token = ""; login = user.login; repositories = []; page = 1
                let rows: [GitHubRepository] = try await get("user/repos?per_page=100&page=1&sort=updated", token: credential)
                repositories = rows; hasMore = rows.count == 100
            } catch { message = error.localizedDescription }
        }
    }
    private func loadMore() {
        guard !busy, let credential = savedToken else { return }
        busy = true
        Task {
            defer { busy = false }
            do {
                let rows: [GitHubRepository] = try await get("user/repos?per_page=100&page=\(page + 1)&sort=updated", token: credential)
                let known = Set(repositories.map(\.id))
                repositories += rows.filter { !known.contains($0.id) }; page += 1; hasMore = rows.count == 100
            } catch { message = error.localizedDescription }
        }
    }
    private func get<T: Decodable>(_ path: String, token: String) async throws -> T {
        var request = URLRequest(url: URL(string: "https://api.github.com/" + path)!)
        request.timeoutInterval = 20
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2026-03-10", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("ServerIDE", forHTTPHeaderField: "User-Agent")
        let session = URLSession(configuration: .ephemeral)
        defer { session.finishTasksAndInvalidate() }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(http.statusCode) else {
            throw RemoteFileFailure(message: "GitHub HTTP \(http.statusCode). Check token expiry, repository access, organization approval or rate limits.")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
