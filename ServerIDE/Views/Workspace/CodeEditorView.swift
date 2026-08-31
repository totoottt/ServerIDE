import SwiftUI

struct CodeEditorView: View {
    let filename: String
    @State private var text: String

    init(filename: String, initialText: String) {
        self.filename = filename
        _text = State(initialValue: initialText)
    }

    var body: some View {
        TextEditor(text: $text)
            .font(.system(size: 15, design: .monospaced))
            .padding(8)
            .navigationTitle(filename)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button {
                    // Remote save will be wired to SFTP.
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
            }
    }
}
