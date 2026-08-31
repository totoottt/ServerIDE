import SwiftUI
import UIKit

struct TerminalView: View {
    let server: ServerProfile
    @ObservedObject private var model: TerminalViewModel
    @StateObject private var selection = TerminalSelectionController()
    @FocusState private var commandFocused: Bool
    @AppStorage("terminalTheme") private var theme = "classic"
    @AppStorage("terminalFontSize") private var fontSize = 18.0
    @AppStorage("terminalWrapLines") private var wrapLines = true
    @State private var transcriptMessage: String?
    @State private var confirmTranscript = false
    @State private var search = ""
    @State private var showSearch = false
    @State private var followOutput = true

    init(model: TerminalViewModel) {
        self.server = model.server
        self.model = model
    }
    private var ink: Color {
        switch theme {
        case "ocean": return .cyan
        case "amber": return .yellow
        case "paper": return .black
        default: return .green
        }
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Circle().fill(model.isRunning ? Color.orange : Color.secondary).frame(width: 7, height: 7)
                Text(model.isRunning ? "EXECUTING" : "COMMAND CONSOLE").font(.caption2.bold().monospaced())
                Spacer()
                Text(server.host).font(.caption.monospaced()).lineLimit(1)
            }.foregroundStyle(.secondary).padding(12)
            if showSearch {
                HStack {
                    TextField("Search output", text: $search).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Find") { selection.find(search) }
                }.padding(.horizontal).padding(.bottom, 8)
            }
            SelectableTerminalOutput(text: model.output, fontSize: fontSize, ink: ink,
                background: theme == "paper" ? .white : .black,
                followOutput: followOutput, wrapLines: wrapLines, controller: selection)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    control("A−", "textformat.size.smaller") { fontSize = max(14, fontSize - 1) }
                    control("A+", "textformat.size.larger") { fontSize = min(34, fontSize + 1) }
                    control(wrapLines ? "Wrap on" : "Wrap off", "text.alignleft") { wrapLines.toggle() }
                    control("Select freely", "selection.pin.in.out") {
                        commandFocused = false
                        selection.beginFreeSelection()
                    }
                    control("Select all", "selection.pin.in.out") { commandFocused = false; selection.selectAll() }
                    control("Copy", "doc.on.doc") { selection.copySelection() }
                    control("Copy all", "doc.on.doc.fill") { UIPasteboard.general.string = model.output }
                    control("Paste", "doc.on.clipboard") {
                        if let text = UIPasteboard.general.string { model.command += text }
                        commandFocused = true
                    }
                    control("Search", "magnifyingglass") { showSearch.toggle() }
                    control("Save transcript", "record.circle") { confirmTranscript = true }
                    control(followOutput ? "Follow on" : "Follow off", "arrow.down.to.line") { followOutput.toggle() }
                    control("Keyboard", "keyboard.chevron.compact.down") { commandFocused = false; selection.textView?.resignFirstResponder() }
                }.padding(10)
            }.background(.bar)
            HStack(spacing: 10) {
                Menu {
                    if model.history.isEmpty { Text("No commands this session") }
                    ForEach(Array(model.history.enumerated()), id: \.offset) { entry in
                        Button(entry.element) { model.command = entry.element; commandFocused = true }
                    }
                } label: { Image(systemName: "clock.arrow.circlepath") }
                    .accessibilityLabel("Session command history")
                TextField("Command…", text: $model.command)
                    .font(.system(size: max(17, fontSize), design: .monospaced))
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                    .focused($commandFocused).submitLabel(.send)
                    .onSubmit { model.run() }
                Button { model.run() } label: {
                    if model.isRunning { ProgressView() }
                    else { Image(systemName: "arrow.up.circle.fill").font(.title) }
                }.disabled(model.isRunning || model.command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.padding()
            Text("Select freely starts iOS selection handles: drag them over any letters or symbols such as / . ( ) & then tap Copy. This tab remembers its folder. Full-screen interactive apps still require PTY mode.")
                .font(.caption2).foregroundStyle(.secondary).padding(.horizontal).padding(.bottom, 8)
        }
        .navigationTitle(server.name).navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Existing installations may have the older 14pt default saved.
            if fontSize < 18 { fontSize = 18 }
            model.connect()
        }
        .confirmationDialog("Save terminal transcript?", isPresented: $confirmTranscript, titleVisibility: .visible) {
            Button("Save encrypted snapshot") {
                do {
                    try TranscriptStore.shared.save(server: server, text: model.output)
                    transcriptMessage = "Saved. Open Recordings from the server menu."
                } catch { transcriptMessage = error.localizedDescription }
            }
        } message: { Text("Commands and output may contain secrets. This saves a text snapshot, not a video or continuous session recording.") }
        .alert("Transcript", isPresented: Binding(get: { transcriptMessage != nil }, set: { if !$0 { transcriptMessage = nil } })) {
            Button("OK") { transcriptMessage = nil }
        } message: { Text(transcriptMessage ?? "") }
    }
    private func control(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(title, systemImage: icon).font(.caption) }.buttonStyle(.bordered)
    }
}
