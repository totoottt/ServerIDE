import Foundation
import Network

struct IPLookupService {
    let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    static func validAddress(_ address: String) -> Bool {
        IPv4Address(address) != nil || IPv6Address(address) != nil
    }

    func lookup(_ ip: String? = nil) async throws -> IPInfo {
        var address = ip?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var addressSource = "Entered address"
        if address.isEmpty {
            (address, addressSource) = try await publicAddress()
        }
        guard Self.validAddress(address) else {
            throw RemoteFileFailure(message: "Enter a valid IPv4 or IPv6 address, not a URL or hostname.")
        }
        var providerErrors: [String] = []
        do {
            let url = URL(string: "https://ipapi.co/")!.appendingPathComponent(address).appendingPathComponent("json/")
            let data = try await request(url)
            if let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any], (payload["error"] as? Bool) == true {
                let reason = (payload["reason"] as? String) ?? "request rejected"
                throw RemoteFileFailure(message: "Location service: \(reason)")
            }
            let info = try JSONDecoder().decode(IPInfo.self, from: data)
            guard let returnedAddress = info.ip, Self.validAddress(returnedAddress) else {
                throw RemoteFileFailure(message: "Location service returned no valid IP address.")
            }
            return IPInfo(ip: info.ip, city: info.city, region: info.region, country_name: info.country_name,
                          org: info.org, timezone: info.timezone,
                          notice: "Address source: \(addressSource). Location source: ipapi.co.")
        } catch {
            if error is CancellationError || (error as? URLError)?.code == .cancelled { throw error }
            providerErrors.append("ipapi.co: \(error.localizedDescription)")
        }
        do {
            struct IPWho: Decodable {
                struct Connection: Decodable { let isp: String? }
                struct Timezone: Decodable { let id: String? }
                let success: Bool?
                let ip: String?
                let city: String?
                let region: String?
                let country: String?
                let connection: Connection?
                let timezone: Timezone?
                let message: String?
            }
            let url = URL(string: "https://ipwho.is/")!.appendingPathComponent(address)
            let data = try await request(url)
            let payload = try JSONDecoder().decode(IPWho.self, from: data)
            guard payload.success != false, let returned = payload.ip, Self.validAddress(returned) else {
                throw RemoteFileFailure(message: payload.message ?? "No valid address returned")
            }
            return IPInfo(ip: returned, city: payload.city, region: payload.region, country_name: payload.country,
                          org: payload.connection?.isp, timezone: payload.timezone?.id,
                          notice: "Address source: \(addressSource). Location source: ipwho.is fallback.")
        } catch {
            if error is CancellationError || (error as? URLError)?.code == .cancelled { throw error }
            providerErrors.append("ipwho.is: \(error.localizedDescription)")
            return IPInfo(ip: address, city: nil, region: nil, country_name: nil, org: nil, timezone: nil,
                          notice: "IP address works (\(addressSource)); optional location providers failed. \(providerErrors.joined(separator: " | "))")
        }
    }

    private func publicAddress() async throws -> (String, String) {
        struct PublicAddress: Decodable { let ip: String }
        var errors: [String] = []
        for (name, url) in [
            ("api64.ipify.org", URL(string: "https://api64.ipify.org?format=json")!),
            ("api.ipify.org", URL(string: "https://api.ipify.org?format=json")!)
        ] {
            do {
                let data = try await request(url)
                let value = try JSONDecoder().decode(PublicAddress.self, from: data).ip
                if Self.validAddress(value) { return (value, name) }
            } catch {
                if error is CancellationError || (error as? URLError)?.code == .cancelled { throw error }
                errors.append("\(name): \(error.localizedDescription)")
            }
        }
        do {
            let data = try await request(URL(string: "https://www.cloudflare.com/cdn-cgi/trace")!)
            let text = String(decoding: data, as: UTF8.self)
            if let line = text.split(whereSeparator: { $0.isNewline }).first(where: { $0.hasPrefix("ip=") }) {
                let value = String(line.dropFirst(3))
                if Self.validAddress(value) { return (value, "Cloudflare trace") }
            }
            throw RemoteFileFailure(message: "Cloudflare returned no valid IP")
        } catch {
            if error is CancellationError || (error as? URLError)?.code == .cancelled { throw error }
            errors.append("Cloudflare: \(error.localizedDescription)")
        }
        throw RemoteFileFailure(message: "Public IP services unavailable. \(errors.joined(separator: " | "))")
    }

    private func request(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(http.statusCode) else {
            let detail = http.statusCode == 429 ? "Rate limit reached. Wait before another lookup." : HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw RemoteFileFailure(message: "\(url.host ?? "IP service"): HTTP \(http.statusCode). \(detail)")
        }
        return data
    }
}
