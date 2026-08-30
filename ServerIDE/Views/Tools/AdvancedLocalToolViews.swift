import SwiftUI
import UniformTypeIdentifiers
import CryptoKit
import UIKit

struct CronGeneratorView: View {
    @State private var minute = "0"
    @State private var hour = "*"
    @State private var day = "*"
    @State private var month = "*"
    @State private var weekday = "*"
    @State private var output = ""
    var body: some View {
        Form {
            Section("Five-field cron") {
                cronField("Minute", text: $minute, hint: "0-59")
                cronField("Hour", text: $hour, hint: "0-23")
                cronField("Day of month", text: $day, hint: "1-31")
                cronField("Month", text: $month, hint: "1-12")
                cronField("Weekday", text: $weekday, hint: "0-7")
                Button("Generate") {
                    do { output = try CronExpression(minute: minute, hour: hour, day: day, month: month, weekday: weekday).value }
                    catch { output = error.localizedDescription }
                }
                Text("Examples: */5 every five units, 1,15 for a list, 1-5 for a range. Verify command paths and timezone on Ubuntu before installing a cron entry.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !output.isEmpty { ToolOutput(text: output) }
        }.scrollContentBackground(.hidden).background(StudioBackground()).navigationTitle("Cron Generator")
    }
    private func cronField(_ title: String, text: Binding<String>, hint: String) -> some View {
        HStack { Text(title); Spacer(); TextField(hint, text: text).multilineTextAlignment(.trailing).keyboardType(.numbersAndPunctuation) }
    }
}

struct HexViewerView: View {
    @State private var importer = false
    @State private var fileName = ""
    @State private var output = ""
    @State private var errorMessage: String?
    var body: some View {
        Form {
            Section("Local file") {
                Button("Open file", systemImage: "doc.badge.plus") { importer = true }
                if !fileName.isEmpty { LabeledContent("File", value: fileName) }
                Text("Reads at most 64 KiB and never uploads the file. Each row shows offset, hexadecimal bytes and printable ASCII.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !output.isEmpty { ToolOutput(text: output) }
        }.scrollContentBackground(.hidden).background(StudioBackground()).navigationTitle("Hex Viewer")
            .fileImporter(isPresented: $importer, allowedContentTypes: [.data], allowsMultipleSelection: false) { result in
                do {
                    guard let url = try result.get().first else { return }
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    let handle = try FileHandle(forReadingFrom: url)
                    defer { try? handle.close() }
                    let data = try handle.read(upToCount: 65_536) ?? Data()
                    fileName = url.lastPathComponent
                    output = Self.render(data)
                } catch { errorMessage = error.localizedDescription }
            }
            .alert("Hex Viewer", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
    }
    static func render(_ data: Data) -> String {
        if data.isEmpty { return "[Empty file]" }
        let bytes = [UInt8](data)
        return stride(from: 0, to: bytes.count, by: 16).map { offset in
            let row = Array(bytes[offset..<min(offset + 16, bytes.count)])
            let hex = row.map { byte in
                let value = String(byte, radix: 16, uppercase: true)
                return value.count == 1 ? "0" + value : value
            }.joined(separator: " ").padding(toLength: 47, withPad: " ", startingAt: 0)
            let ascii = row.map { byte in
                (32...126).contains(byte) ? String(bytes: [byte], encoding: .ascii) ?? "." : "."
            }.joined()
            let rawOffset = String(offset, radix: 16, uppercase: true)
            let offsetText = String(repeating: "0", count: max(0, 8 - rawOffset.count)) + rawOffset
            return "\(offsetText)  \(hex)  |\(ascii)|"
        }.joined(separator: "\n")
    }
}

struct EncryptedSecretView: View {
    private struct Package: Codable { let salt: Data; let sealed: Data }
    @State private var mode = "Encrypt"
    @State private var input = ""
    @State private var passphrase = ""
    @State private var output = ""
    var body: some View {
        Form {
            Section("Portable encrypted payload") {
                Picker("Mode", selection: $mode) {
                    Text("Encrypt").tag("Encrypt")
                    Text("Decrypt").tag("Decrypt")
                }.pickerStyle(.segmented)
                SecureField("Long passphrase", text: $passphrase)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                TextEditor(text: $input).frame(minHeight: 140)
                    .font(.system(.body, design: .monospaced))
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Button(mode) {
                    do { output = mode == "Encrypt" ? try Self.encrypt(input, passphrase: passphrase) : try Self.decrypt(input, passphrase: passphrase) }
                    catch { output = "Error: \(error.localizedDescription)" }
                }.disabled(input.isEmpty || passphrase.count < 12)
                Text("Uses AES-GCM on this device. Share the payload and passphrase through different channels. This offline version cannot enforce expiry dates or view counts.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !output.isEmpty { ToolOutput(text: output) }
        }.scrollContentBackground(.hidden).background(StudioBackground()).navigationTitle("Secret Share")
            .onDisappear { input = ""; passphrase = ""; output = "" }
    }
    static func encrypt(_ text: String, passphrase: String) throws -> String {
        guard passphrase.count >= 12 else { throw RemoteFileFailure(message: "Use a passphrase of at least 12 characters.") }
        let salt = Data((0..<16).map { _ in UInt8.random(in: UInt8.min ... UInt8.max) })
        let key = derive(passphrase, salt: salt)
        guard let combined = try AES.GCM.seal(Data(text.utf8), using: key).combined else {
            throw RemoteFileFailure(message: "Could not create encrypted payload.")
        }
        return try JSONEncoder().encode(Package(salt: salt, sealed: combined)).base64EncodedString()
    }
    static func decrypt(_ payload: String, passphrase: String) throws -> String {
        guard let data = Data(base64Encoded: payload.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw RemoteFileFailure(message: "Invalid encrypted payload.")
        }
        let package = try JSONDecoder().decode(Package.self, from: data)
        let box = try AES.GCM.SealedBox(combined: package.sealed)
        let clear = try AES.GCM.open(box, using: derive(passphrase, salt: package.salt))
        guard let text = String(data: clear, encoding: .utf8) else { throw RemoteFileFailure(message: "Decrypted data is not UTF-8 text.") }
        return text
    }
    private static func derive(_ passphrase: String, salt: Data) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: Data(passphrase.utf8)),
                               salt: salt, info: Data("ServerIDE Secret Share v1".utf8), outputByteCount: 32)
    }
}
