import Foundation

struct IPInfo: Codable, Sendable {
    let ip: String?
    let city: String?
    let region: String?
    let country_name: String?
    let org: String?
    let timezone: String?
    var notice: String? = nil
}
