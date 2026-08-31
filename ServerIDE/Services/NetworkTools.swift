import Foundation

struct HTTPInspection: Sendable {
    let status: Int
    let finalURL: String
    let headers: String
    let body: String
    let elapsed: TimeInterval
    let truncated: Bool
}

enum NetworkTools {
    static func inspect(url input: String, method: String, body: String = "") async throws -> HTTPInspection {
        guard let url = URL(string: input.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              url.host != nil, url.user == nil, url.password == nil else { throw ToolInputError.invalidURL }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.httpShouldSetCookies = false
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: url)
        request.httpMethod = method
        if !body.isEmpty && method != "GET" && method != "HEAD" {
            request.httpBody = Data(body.utf8)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let start = Date()
        let (bytes, response) = try await session.bytes(for: request)
        var data = Data()
        var truncated = false
        for try await byte in bytes {
            try Task.checkCancellation()
            if data.count >= 262_144 { truncated = true; break }
            data.append(byte)
        }
        let http = response as? HTTPURLResponse
        let headers = (http?.allHeaderFields ?? [:]).map { "\($0.key): \($0.value)" }.sorted().joined(separator: "\n")
        return HTTPInspection(status: http?.statusCode ?? 0, finalURL: response.url?.absoluteString ?? input,
                              headers: headers, body: String(data: data, encoding: .utf8) ?? "[Binary / non-UTF8 response: \(data.count) bytes]",
                              elapsed: Date().timeIntervalSince(start), truncated: truncated)
    }

    static func dns(host: String, type: String) async throws -> String {
        let host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty, host.count <= 253,
              host.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_").contains($0) }) else {
            throw ToolInputError.invalidURL
        }
        var url = URLComponents(string: "https://dns.google/resolve")!
        url.queryItems = [URLQueryItem(name: "name", value: host), URLQueryItem(name: "type", value: type)]
        let response = try await inspect(url: url.url!.absoluteString, method: "GET")
        guard response.status == 200 else {
            return "DNS provider returned HTTP \(response.status)\n\(response.body)"
        }
        return try TextTransform.jsonPretty.apply(response.body)
    }
}
