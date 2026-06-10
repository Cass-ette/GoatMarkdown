import SwiftUI

struct NoteEditorSheet: View {
    let highlightID: UUID
    @Binding var isPresented: Bool
    var initialNote: String
    var onSave: (UUID, String?) -> Void

    @State private var text: String = ""
    private static let maxNoteLength = 500

    init(highlightID: UUID, isPresented: Binding<Bool>, initialNote: String?, onSave: @escaping (UUID, String?) -> Void) {
        self.highlightID = highlightID
        self._isPresented = isPresented
        self.initialNote = initialNote ?? ""
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Note")
                .font(.headline)

            TextEditor(text: $text)
                .font(.body)
                .frame(minHeight: 80, maxHeight: 120)
                .border(Color.secondary.opacity(0.3))
                .onChange(of: text) { _, newValue in
                    if newValue.count > Self.maxNoteLength {
                        text = String(newValue.prefix(Self.maxNoteLength))
                    }
                }

            Text("\(text.count)/\(Self.maxNoteLength)")
                .font(.caption)
                .foregroundStyle(text.count >= Self.maxNoteLength ? .red : .secondary)

            HStack {
                if !initialNote.isEmpty {
                    Button("Delete Note", role: .destructive) {
                        onSave(highlightID, nil)
                        isPresented = false
                    }
                }
                Spacer()
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                Button("Save") {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSave(highlightID, trimmed.isEmpty ? nil : trimmed)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && initialNote.isEmpty)
            }
        }
        .padding()
        .frame(width: 320)
        .onAppear {
            text = initialNote
        }
    }
}
