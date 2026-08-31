import SwiftUI
import UIKit

struct ToolOutput: View {
    let text: String
    var body: some View {
        Section("Result") {
            Text(text).font(.system(.callout, design: .monospaced)).textSelection(.enabled)
            Button { UIPasteboard.general.string = text } label: { Label("Copy result", systemImage: "doc.on.doc") }
                .disabled(text.isEmpty)
        }
    }
}

struct SubnetLabView: View {
    @State private var input = "192.168.1.15/24"
    @State private var output = ""
    var body: some View {
        Form {
            Section("IPv4 subnet") {
                TextField("IPv4/CIDR", text: $input).keyboardType(.numbersAndPunctuation)
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                Button("Calculate locally") {
                    do {
                        let subnet = try IPv4Subnet(input)
                        output = "Network: \(subnet.network)\nMask: \(subnet.mask)\nLast address: \(subnet.broadcast)\nFirst host: \(subnet.firstHost)\nLast host: \(subnet.lastHost)\nAddresses: \(subnet.addresses)\nUsable hosts: \(subnet.usableHosts)"
                    } catch { output = error.localizedDescription }
                }
                Text("/31 uses point-to-point semantics; /32 is a single host. No network request is made.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !output.isEmpty { ToolOutput(text: output) }
        }.scrollContentBackground(.hidden).background(StudioBackground()).navigationTitle("Subnet Lab")
    }
}

struct TextLabView: View {
    @State private var input = ""
    @State private var operation = TextTransform.base64Encode
    @State private var output = ""
    var body: some View {
        Form {
            Section("Local transformation") {
                Picker("Operation", selection: $operation) {
                    ForEach(TextTransform.allCases) { Text($0.rawValue).tag($0) }
                }
                TextEditor(text: $input).frame(minHeight: 150)
                    .font(.system(.body, design: .monospaced))
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                Button("Transform") {
                    do { output = try operation.apply(input) }
                    catch { output = error.localizedDescription }
                }.disabled(input.isEmpty)
                Text("Runs on your device. Base64 is encoding, not encryption.").font(.caption).foregroundStyle(.secondary)
            }
            if !output.isEmpty { ToolOutput(text: output) }
        }.scrollContentBackground(.hidden).background(StudioBackground()).navigationTitle("Text Lab")
    }
}

struct PasswordLabView: View {
    @State private var length = 24.0
    @State private var symbols = true
    @State private var password = ""
    var body: some View {
        Form {
            Section("Password generator") {
                LabeledContent("Length", value: "\(Int(length))")
                Slider(value: $length, in: 12...128, step: 1)
                Toggle("Include symbols", isOn: $symbols)
                Button("Generate locally") {
                    password = PasswordGenerator.generate(length: Int(length), symbols: symbols)
                }
            }
            if !password.isEmpty {
                Section("Generated password") {
                    Text(password).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                    Button("Copy for 60 seconds") {
                        UIPasteboard.general.setItems([[UIPasteboard.typeAutomatic: password]],
                            options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(60)])
                    }
                    Button("Clear", role: .destructive) { password = "" }
                }
            }
            Section {
                Text("Generated using the system random number generator. Not saved to history or sent to a server. A password is not guaranteed to include every character category.").font(.caption).foregroundStyle(.secondary)
            }
        }.scrollContentBackground(.hidden).background(StudioBackground()).navigationTitle("Password Lab")
            .onDisappear { password = "" }
    }
}
