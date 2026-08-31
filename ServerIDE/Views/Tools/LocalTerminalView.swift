import SwiftUI

struct LocalTerminalView: View {
    @State private var engine: LocalCommandEngine?
    @State private var input = ""
    @State private var output = "Local Documents terminal. Type help.\nThis is not a Linux shell.\n"
    @StateObject private var selection = TerminalSelectionController()
    var body: some View {
        VStack(spacing: 0) {
            SelectableTerminalOutput(text: output, fontSize: 15, ink: .green, background: .black,
                                     followOutput: true, wrapLines: true, controller: selection)
            HStack {
                TextField("Command…", text: $input).font(.body.monospaced())
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                    .submitLabel(.send).onSubmit { execute() }
                Button("Run", systemImage: "arrow.up.circle.fill") { execute() }.disabled(engine == nil)
            }.padding()
        }
        .navigationTitle("Local Terminal")
        .task {
            guard engine == nil else { return }
            do {
                try LocalFilesStore.prepare()
                let root = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                engine = try LocalCommandEngine(root: root)
            } catch { output += error.localizedDescription }
        }
    }
    private func execute() {
        guard let engine, !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let command = input; input = ""
        do {
            let result = try engine.run(command)
            if command.trimmingCharacters(in: .whitespacesAndNewlines) == "clear" { output = "" }
            else { output += "\n\(engine.prompt) \(command)\n\(result)\n" }
        } catch { output += "\nError: \(error.localizedDescription)\n" }
        if output.count > 65536 { output = "[Older output trimmed]\n" + String(output.suffix(65536)) }
    }
}
