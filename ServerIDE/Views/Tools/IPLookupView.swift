import SwiftUI

struct IPLookupView: View {
    @State private var ip = ""
    @State private var info: IPInfo?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("IP Address") {
                TextField("Leave empty for your public IP", text: $ip)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button(isLoading ? "Checking..." : "Lookup") {
                    lookup()
                }
                .disabled(isLoading)
                Text("Public IP uses ipify; location details use ipapi.co. These requests leave your device.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if let info {
                Section("Result") {
                    row("IP", info.ip)
                    row("Country", info.country_name)
                    row("Region", info.region)
                    row("City", info.city)
                    row("Organization", info.org)
                    row("Timezone", info.timezone)
                    if let notice = info.notice { Text(notice).font(.caption).foregroundStyle(.secondary) }
                }
            }

            if let errorMessage {
                Section("Error") {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("IP Lookup")
    }

    @ViewBuilder
    private func row(_ title: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            LabeledContent(title, value: value)
        }
    }

    private func lookup() {
        isLoading = true
        errorMessage = nil
        info = nil
        Task {
            do {
                info = try await IPLookupService().lookup(ip.isEmpty ? nil : ip)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
