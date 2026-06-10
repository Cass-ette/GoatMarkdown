import SwiftUI

struct TagEditorSheet: View {
    let bookmarkID: UUID
    @Binding var isPresented: Bool
    var initialTags: [String]
    var existingTags: [String]
    var onSave: (UUID, [String]) -> Void

    @State private var text: String = ""

    init(bookmarkID: UUID, isPresented: Binding<Bool>, initialTags: [String], existingTags: [String], onSave: @escaping (UUID, [String]) -> Void) {
        self.bookmarkID = bookmarkID
        self._isPresented = isPresented
        self.initialTags = initialTags
        self.existingTags = existingTags
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tags")
                .font(.headline)

            TextField("Enter tags (comma-separated)", text: $text)
                .textFieldStyle(.plain)
                .font(.body)
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            if !suggestedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(suggestedTags, id: \.self) { tag in
                            Button {
                                appendTag(tag)
                            } label: {
                                TagPillView(tag: tag)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if !currentTags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(currentTags, id: \.self) { tag in
                        TagPillView(tag: tag)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                Button("Save") {
                    onSave(bookmarkID, currentTags)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 320)
        .onAppear {
            text = initialTags.joined(separator: ", ")
        }
    }

    private var currentTags: [String] {
        text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var suggestedTags: [String] {
        existingTags.filter { tag in
            !currentTags.contains(tag)
        }
    }

    private func appendTag(_ tag: String) {
        let current = currentTags
        if !current.contains(tag) {
            if text.isEmpty {
                text = tag
            } else {
                text += ", \(tag)"
            }
        }
    }
}
