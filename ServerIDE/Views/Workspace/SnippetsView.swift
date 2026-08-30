import SwiftUI
import UIKit

struct SnippetsView: View {
    let server: ServerProfile
    @StateObject private var store = SnippetStore()
    @State private var search = ""
    @State private var favoritesOnly = false
    @State private var draft: CommandSnippet?
    @State private var pending: CommandSnippet?
    @State private var output = ""
    @State private var running = false
    @State private var deleting: CommandSnippet?

    private var filtered: [CommandSnippet] {
        store.items.filter {
            (!favoritesOnly || $0.favorite) &&
            (search.isEmpty || ($0.title + " " + $0.command + " " + $0.category).localizedCaseInsensitiveContains(search))
        }.sorted {
            if $0.favorite != $1.favorite { return $0.favorite }
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    var body: some View {
        List {
            Section {
                Toggle("Favorites only", isOn: $favoritesOnly)
                Text("Commands run on \(server.name). Review before execution. Do not save passwords or tokens in commands.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Command library · \(filtered.count)") {
                ForEach(filtered) { snippet in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(snippet.title).font(.headline)
                            Spacer()
                            Button { store.favorite(snippet.id) } label: {
                                Image(systemName: snippet.favorite ? "star.fill" : "star")
                            }.buttonStyle(.borderless).accessibilityLabel("Toggle favorite")
                        }
                        Text(snippet.category.uppercased()).font(.caption2.bold()).foregroundStyle(.secondary)
                        Text(snippet.command).font(.system(.caption, design: .monospaced)).lineLimit(3)
                        HStack {
                            Button { pending = snippet } label: { Label("Run", systemImage: "play.fill") }
                                .disabled(running)
                            Spacer()
                            Button { UIPasteboard.general.string = snippet.command } label: { Image(systemName: "doc.on.doc") }
                                .accessibilityLabel("Copy command")
                            Button { draft = snippet } label: { Image(systemName: "pencil") }.accessibilityLabel("Edit command")
                            Button(role: .destructive) { deleting = snippet } label: { Image(systemName: "trash") }
                                .accessibilityLabel("Delete saved command")
                        }.buttonStyle(.borderless)
                    }.padding(.vertical, 8)
                }
                if filtered.isEmpty { Text("No matching commands. Use + to add one.").foregroundStyle(.secondary) }
            }
            if running { Section { ProgressView("Executing on \(server.name)…") } }
            if !output.isEmpty { ToolOutput(text: output) }
        }
        .scrollContentBackground(.hidden).background(StudioBackground())
        .navigationTitle("Command Vault").searchable(text: $search)
        .toolbar {
            Button {
                draft = CommandSnippet(title: "", command: "", category: "Personal")
            } label: { Image(systemName: "plus") }.accessibilityLabel("Add command")
        }
        .sheet(item: $draft) { snippet in
            SnippetEditorView(snippet: snippet) { store.save($0) }
        }
        .alert("Run command on \(server.name)?", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } })) {
            Button("Cancel", role: .cancel) { pending = nil }
            Button("Run") {
                if let snippet = pending { execute(snippet) }
                pending = nil
            }
        } message: { Text(pending?.command ?? "") }
        .alert("Delete saved command?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Cancel", role: .cancel) { deleting = nil }
            Button("Delete", role: .destructive) {
                if let snippet = deleting { store.delete(snippet.id) }
                deleting = nil
            }
        } message: { Text("This only removes the saved snippet; it does not delete anything on the server.") }
        .alert("Command storage", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK") { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
    }

    private func execute(_ snippet: CommandSnippet) {
        guard !running else { return }
        running = true
        output = "$ \(snippet.command)\n\n"
        Task { @MainActor in
            defer { running = false }
            do { output += try await SSHConnectionManager.shared.execute(snippet.command, on: server) }
            catch { output += "\nError: \(error.localizedDescription)" }
        }
    }
}

private struct SnippetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State var snippet: CommandSnippet
    let save: (CommandSnippet) -> Void
    private var valid: Bool {
        !snippet.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !snippet.command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $snippet.title)
                TextField("Category", text: $snippet.category)
                Section("Command") {
                    TextEditor(text: $snippet.command).frame(minHeight: 180)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled().textInputAutocapitalization(.never)
                }
                Toggle("Favorite", isOn: $snippet.favorite)
                Text("Saved on this device in app preferences. Do not include secrets.").font(.caption).foregroundStyle(.secondary)
            }.navigationTitle("Edit command")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { save(snippet); dismiss() }.disabled(!valid)
                    }
                }
        }
    }
}
