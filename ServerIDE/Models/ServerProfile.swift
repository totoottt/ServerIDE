import Foundation

struct ServerProfile: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var host: String
    var port: Int = 22
    var username: String
    var group: String = "Personal"
    var notes: String = ""
    var authenticationType: SSHAuthenticationType = .password
    var previewURL: String = ""
    var isFavorite: Bool? = nil
    var lastUsed: Date? = nil
}
