import SwiftUI
import WebKit

struct WebPreviewView: View {
    @State private var urlText: String
    @State private var currentURL: URL?

    init(initialURL: String) {
        _urlText = State(initialValue: initialURL)
        _currentURL = State(initialValue: Self.makeURL(initialURL))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("URL", text: $urlText)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .onSubmit { currentURL = Self.makeURL(urlText) }

                Button("Go") { currentURL = Self.makeURL(urlText) }
                    .buttonStyle(.borderedProminent)
            }
            .padding()

            if let currentURL {
                WebView(url: currentURL)
            } else {
                ContentUnavailableView("Invalid URL", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
    }

    private static func makeURL(_ raw: String) -> URL? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if let url = URL(string: value), url.scheme != nil { return url }
        return URL(string: "https://" + value)
    }
}

private struct WebView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView { WKWebView() }
    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url != url { webView.load(URLRequest(url: url)) }
    }
}
