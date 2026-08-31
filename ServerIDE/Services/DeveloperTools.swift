import Foundation

enum ToolInputError: LocalizedError {
    case invalidCIDR, invalidBase64, invalidURL, invalidJSON
    var errorDescription: String? {
        switch self {
        case .invalidCIDR: return "Enter IPv4/CIDR, for example 192.168.1.15/24."
        case .invalidBase64: return "Input is not valid UTF-8 Base64."
        case .invalidURL: return "Enter an HTTP or HTTPS URL without embedded credentials."
        case .invalidJSON: return "Input is not valid JSON."
        }
    }
}

struct IPv4Subnet {
    let network: String
    let mask: String
    let broadcast: String
    let firstHost: String
    let lastHost: String
    let addresses: UInt64
    let usableHosts: UInt64

    init(_ input: String) throws {
        let fields = input.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "/", omittingEmptySubsequences: false)
        guard fields.count == 2, let prefix = Int(fields[1]), (0...32).contains(prefix) else {
            throw ToolInputError.invalidCIDR
        }
        let parts = fields[0].split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { throw ToolInputError.invalidCIDR }
        var ip: UInt32 = 0
        for part in parts {
            guard !part.isEmpty, part.allSatisfy({ $0.isASCII && $0.isNumber }),
                  let octet = UInt8(part) else { throw ToolInputError.invalidCIDR }
            ip = (ip << 8) | UInt32(octet)
        }
        let bits: UInt32 = prefix == 0 ? 0 : UInt32.max << (32 - prefix)
        let net = ip & bits
        let last = net | ~bits
        addresses = UInt64(1) << (32 - prefix)
        usableHosts = prefix >= 31 ? addresses : addresses - 2
        network = Self.format(net)
        mask = Self.format(bits)
        broadcast = Self.format(last)
        firstHost = Self.format(prefix >= 31 ? net : net + 1)
        lastHost = Self.format(prefix >= 31 ? last : last - 1)
    }

    private static func format(_ value: UInt32) -> String {
        [24, 16, 8, 0].map { String((value >> $0) & 255) }.joined(separator: ".")
    }
}

enum TextTransform: String, CaseIterable, Identifiable {
    case base64Encode = "Base64 encode"
    case base64Decode = "Base64 decode"
    case urlEncode = "URL encode"
    case urlDecode = "URL decode"
    case jsonPretty = "Format JSON"
    var id: String { rawValue }

    func apply(_ input: String) throws -> String {
        switch self {
        case .base64Encode: return Data(input.utf8).base64EncodedString()
        case .base64Decode:
            guard let data = Data(base64Encoded: input.trimmingCharacters(in: .whitespacesAndNewlines)),
                  let result = String(data: data, encoding: .utf8) else { throw ToolInputError.invalidBase64 }
            return result
        case .urlEncode:
            return input.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")) ?? input
        case .urlDecode:
            guard let result = input.removingPercentEncoding else { throw ToolInputError.invalidURL }
            return result
        case .jsonPretty:
            guard let data = input.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
                  let output = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed]),
                  let text = String(data: output, encoding: .utf8) else { throw ToolInputError.invalidJSON }
            return text
        }
    }
}

enum PasswordGenerator {
    static func generate(length: Int, symbols: Bool) -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789" + (symbols ? "!@#$%&*-_=+?" : ""))
        var random = SystemRandomNumberGenerator()
        return String((0..<max(12, min(128, length))).map { _ in alphabet[Int.random(in: 0..<alphabet.count, using: &random)] })
    }
}

struct CronExpression {
    let minute: String
    let hour: String
    let day: String
    let month: String
    let weekday: String

    var value: String { "\(minute) \(hour) \(day) \(month) \(weekday)" }

    init(minute: String, hour: String, day: String, month: String, weekday: String) throws {
        let fields = [minute, hour, day, month, weekday]
        let allowed = CharacterSet(charactersIn: "0123456789*/,-")
        guard fields.allSatisfy({ !$0.isEmpty && $0.count <= 24 && $0.unicodeScalars.allSatisfy(allowed.contains) }) else {
            throw RemoteFileFailure(message: "Cron fields may contain digits and * / , - only.")
        }
        self.minute = minute; self.hour = hour; self.day = day; self.month = month; self.weekday = weekday
    }
}
