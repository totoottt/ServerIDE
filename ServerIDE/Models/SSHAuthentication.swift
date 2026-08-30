import Foundation

enum SSHAuthenticationType: String, Codable, CaseIterable, Identifiable, Sendable {
    case password
    case privateKey
    var id: String { rawValue }
    var title: String { self == .password ? "Password" : "Private Key" }
}
