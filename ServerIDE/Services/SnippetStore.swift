import Foundation
import Combine

struct CommandSnippet: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var command: String
    var category: String
    var favorite = false
}

@MainActor
final class SnippetStore: ObservableObject {
    @Published private(set) var items: [CommandSnippet] = []
    @Published var errorMessage: String?
    private let defaults: UserDefaults
    private let key = "serveride.snippets.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key) {
            do { items = try JSONDecoder().decode([CommandSnippet].self, from: data) }
            catch { errorMessage = "Saved commands could not be read. Existing saved data was not overwritten." }
        } else { items = Self.starters }
    }
    func save(_ item: CommandSnippet) {
        if let index = items.firstIndex(where: { $0.id == item.id }) { items[index] = item }
        else { items.append(item) }
        persist()
    }
    func delete(_ id: UUID) { items.removeAll { $0.id == id }; persist() }
    func favorite(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].favorite.toggle()
        persist()
    }
    private func persist() {
        do { defaults.set(try JSONEncoder().encode(items), forKey: key) }
        catch { errorMessage = error.localizedDescription }
    }

    static var starters: [CommandSnippet] {
        [
            CommandSnippet(title: "System overview", command: "uname -a; uptime; free -h; df -h /", category: "Ubuntu"),
            CommandSnippet(title: "Memory leaders", command: "ps aux --sort=-%mem | head -15", category: "Ubuntu"),
            CommandSnippet(title: "Listening ports", command: "ss -lntup", category: "Network"),
            CommandSnippet(title: "Docker containers", command: "docker ps -a", category: "Docker"),
            CommandSnippet(title: "Docker resources", command: "docker stats --no-stream", category: "Docker"),
            CommandSnippet(title: "Failed services", command: "systemctl --failed --no-pager", category: "Services"),
            CommandSnippet(title: "Telegram bot status", command: "systemctl status telegrambot --no-pager", category: "Services", favorite: true),
            CommandSnippet(title: "Telegram bot logs", command: "journalctl -u telegrambot -n 100 --no-pager", category: "Logs", favorite: true),
            CommandSnippet(title: "Recent system errors", command: "journalctl -p err -n 50 --no-pager", category: "Logs"),
            CommandSnippet(title: "Python interpreter", command: "command -v python3; python3 --version", category: "Python"),
            CommandSnippet(title: "Telegram DNS", command: "getent hosts api.telegram.org", category: "Network"),
            CommandSnippet(title: "Disk space", command: "df -h; df -i", category: "Ubuntu")
        ]
    }
}
