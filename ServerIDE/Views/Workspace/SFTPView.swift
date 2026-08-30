import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct SFTPView: View {
    let server: ServerProfile
    @StateObject private var model: SFTPViewModel
    @AppStorage("fileFontSize") private var fontSize = 15.0
    @AppStorage("fileWrapNames") private var wrapNames = true
    @AppStorage("showHiddenFiles") private var showHidden = true
    @AppStorage("folderFavorites") private var favoritesData = Data()
    @State private var search = ""
    @State private var prompt: String?
    @State private var input = ""
    @State private var renaming: RemoteFile?
    @State private var deleting: RemoteFile?
    @State private var importer = false
    @State private var uploadFolder = false

    init(server: ServerProfile) {
        self.server = server
        _model = StateObject(wrappedValue: SFTPViewModel(server: server))
    }
    private var favorites: [String: [String]] {
        (try? JSONDecoder().decode([String: [String]].self, from: favoritesData)) ?? [:]
    }
    private var serverFavorites: [String] { favorites[server.id.uuidString] ?? [] }
    private var visible: [RemoteFile] {
        model.files.filter { (showHidden || !$0.name.hasPrefix(".")) && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)) }
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Button { model.goUp() } label: { Image(systemName: "arrow.up.to.line") }
                        .disabled(model.currentPath == "/" || model.isLoading).accessibilityLabel("Parent folder")
                    Text(model.currentPath).font(.system(size: fontSize - 2, design: .monospaced))
                        .lineLimit(wrapNames ? nil : 1).textSelection(.enabled)
                    Spacer()
                    Button { model.load() } label: { Image(systemName: "arrow.clockwise") }.disabled(model.isLoading)
                }
                Text("\(visible.count) items · SSH file operations · Python 3 required")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !model.status.isEmpty {
                Section { Text(model.status).font(.caption).foregroundStyle(.secondary) }
            }
            Section("Folders (\(visible.filter { $0.isDirectory }.count))") {
                fileEntries(visible.filter { $0.isDirectory })
            }
            Section("Files (\(visible.filter { !$0.isDirectory }.count))") {
                fileEntries(visible.filter { !$0.isDirectory })
            }
        }
        .scrollContentBackground(.hidden).background(StudioBackground())
        .searchable(text: $search, prompt: "Find in this folder")
        .navigationTitle("Remote Files").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Menu {
                Button("Create directory", systemImage: "folder.badge.plus") { input = ""; prompt = "Create directory" }
                Button("Create file", systemImage: "doc.badge.plus") { input = ""; prompt = "Create file" }
                Button("Upload file", systemImage: "square.and.arrow.up") { uploadFolder = false; importer = true }
                Button("Upload folder", systemImage: "folder.badge.plus") { uploadFolder = true; importer = true }
                Button(serverFavorites.contains(model.currentPath) ? "Remove folder favorite" : "Favorite this folder", systemImage: "star") { toggleFavorite() }
                Menu("Favorite folders", systemImage: "star.circle") {
                    ForEach(serverFavorites, id: \.self) { path in Button(path) { model.load(path) } }
                    if serverFavorites.isEmpty { Text("No favorite folders") }
                }
                Toggle("Show hidden files", isOn: $showHidden)
                Button("Jump to path", systemImage: "arrow.turn.down.right") { input = model.currentPath; prompt = "Jump to path" }
                Divider()
                Button("Smaller text", systemImage: "textformat.size.smaller") { fontSize = max(10, fontSize - 1) }
                Button("Larger text", systemImage: "textformat.size.larger") { fontSize = min(26, fontSize + 1) }
                Toggle("Wrap filenames", isOn: $wrapNames)
            } label: { Image(systemName: "ellipsis.circle").font(.title3) }.disabled(model.isLoading)
        }
        .overlay { if model.isLoading { ProgressView("Working…").padding().background(.regularMaterial, in: Capsule()) } }
        .onAppear { if model.files.isEmpty { model.load() } }
        .fileImporter(isPresented: $importer, allowedContentTypes: uploadFolder ? [.folder] : [.data], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls): if let url = urls.first { model.upload(url, directory: uploadFolder) }
            case .failure(let error): model.errorMessage = error.localizedDescription
            }
        }
        .alert(prompt ?? "", isPresented: Binding(get: { prompt != nil }, set: { if !$0 { prompt = nil } })) {
            TextField(prompt == "Jump to path" ? "/path" : "Name", text: $input).textInputAutocapitalization(.never).autocorrectionDisabled()
            Button("Cancel", role: .cancel) { prompt = nil }
            Button("Apply") {
                switch prompt {
                case "Create directory": model.create(name: input, directory: true)
                case "Create file": model.create(name: input, directory: false)
                case "Rename": if let file = renaming { model.rename(file, to: input) }
                case "Jump to path": model.load(input)
                default: break
                }
                prompt = nil
            }
        } message: {
            Text(prompt == "Jump to path" ? "Enter an absolute path or ~ for your home directory." : "Existing names are never overwritten. Folder upload includes hidden files; maximum 200 entries / 20 MiB.")
        }
        .alert("Delete \(deleting?.name ?? "")?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Cancel", role: .cancel) { deleting = nil }
            Button("Delete", role: .destructive) { if let file = deleting { model.delete(file) }; deleting = nil }
        } message: { Text("Remote deletion cannot be undone. Only empty directories can be deleted.") }
        .alert("Remote file error", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }
    @ViewBuilder private func fileEntries(_ items: [RemoteFile]) -> some View {
        ForEach(items) { file in
            Group {
                if file.isDirectory {
                    Button { model.openDirectory(file) } label: { fileRow(file) }.buttonStyle(.plain)
                } else {
                    NavigationLink { RemoteCodeEditorView(server: server, file: file) } label: { fileRow(file) }
                }
            }
            .disabled(model.isLoading)
            .contextMenu {
                Button("Rename", systemImage: "pencil") { renaming = file; input = file.name; prompt = "Rename" }
                Button("Copy path", systemImage: "doc.on.doc") { UIPasteboard.general.string = file.path }
                if !file.isDirectory {
                    Button("Download to Files", systemImage: "arrow.down.doc") { model.download(file) }
                }
                Button("Delete", systemImage: "trash", role: .destructive) { deleting = file }
            }
        }
        if items.isEmpty && !model.isLoading { Text("None in this section.").foregroundStyle(.secondary) }
    }
    private func fileRow(_ file: RemoteFile) -> some View {
        HStack(spacing: 14) {
            Image(systemName: file.icon).font(.title3).foregroundStyle(Color.accentColor)
                .frame(width: 38, height: 42).background(Color.accentColor.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                Text(file.name).font(.system(size: fontSize, weight: .semibold)).lineLimit(wrapNames ? nil : 1)
                    .fixedSize(horizontal: false, vertical: true).foregroundStyle(.primary)
                HStack {
                    if let size = file.size {
                        Text(ByteCountFormatter.string(fromByteCount: Int64(clamping: size), countStyle: .file))
                    }
                    if let modified = file.modified { Text(Date(timeIntervalSince1970: modified).formatted(date: .abbreviated, time: .omitted)) }
                }.font(.caption2).foregroundStyle(.secondary)
                if let permissions = file.permissions { Text(permissions).font(.caption2.monospaced()).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 0)
            if file.isDirectory { Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary) }
        }.padding(.vertical, 5)
    }
    private func toggleFavorite() {
        var all = favorites
        var paths = serverFavorites
        if paths.contains(model.currentPath) { paths.removeAll { $0 == model.currentPath } }
        else { paths.append(model.currentPath) }
        all[server.id.uuidString] = paths
        if let data = try? JSONEncoder().encode(all) { favoritesData = data }
    }
}
