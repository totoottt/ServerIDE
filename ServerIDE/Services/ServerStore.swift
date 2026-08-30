import Foundation
import Combine

@MainActor
final class ServerStore: ObservableObject {
    @Published var servers: [ServerProfile] = [] {
        didSet { save() }
    }

    private let key = "serveride.servers"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func add(_ server: ServerProfile) {
        servers.append(server)
    }

    func update(_ server: ServerProfile) {
        guard let index = servers.firstIndex(where: { $0.id == server.id }) else { return }
        servers[index] = server
    }
    func markUsed(_ id: UUID) {
        guard let index = servers.firstIndex(where: { $0.id == id }) else { return }
        servers[index].lastUsed = Date()
    }
    func toggleFavorite(_ id: UUID) {
        guard let index = servers.firstIndex(where: { $0.id == id }) else { return }
        servers[index].isFavorite = !(servers[index].isFavorite ?? false)
    }
    @discardableResult
    func clone(_ source: ServerProfile) -> Bool {
        var copy = source
        copy.id = UUID()
        copy.name += " Copy"
        copy.lastUsed = nil
        guard CredentialStore.clone(from: source.id, to: copy.id) else { return false }
        add(copy)
        return true
    }
    func delete(id: UUID) {
        CredentialStore.remove(for: id)
        servers.removeAll { $0.id == id }
    }

    func delete(at offsets: IndexSet) {
        let ids = offsets.map { servers[$0].id }
        for id in ids { delete(id: id) }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(servers) else { return }
        defaults.set(data, forKey: key)
    }

    private func load() {
        guard
            let data = defaults.data(forKey: key),
            let decoded = try? JSONDecoder().decode([ServerProfile].self, from: data)
        else { return }
        servers = decoded
    }
}
