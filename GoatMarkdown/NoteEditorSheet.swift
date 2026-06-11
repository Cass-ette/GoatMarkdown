import SwiftUI
import AppKit

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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Note")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(text.count)/\(Self.maxNoteLength)")
                    .font(.system(size: 10))
                    .foregroundStyle(text.count >= Self.maxNoteLength ? .red : .secondary)
                    .monospacedDigit()
            }

            TextEditor(text: $text)
                .font(.system(size: 12))
                .scrollContentBackground(.hidden)
                .padding(6)
                .frame(minHeight: 80, maxHeight: 120)
                .background(Color(nsColor: .textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
                .onChange(of: text) { _, newValue in
                    if newValue.count > Self.maxNoteLength {
                        text = String(newValue.prefix(Self.maxNoteLength))
                    }
                }

            HStack(spacing: 6) {
                if !initialNote.isEmpty {
                    Button("Delete") {
                        onSave(highlightID, nil)
                        closeWindow()
                    }
                    .controlSize(.small)
                }
                Spacer()
                Button("Cancel") {
                    closeWindow()
                }
                .controlSize(.small)
                .keyboardShortcut(.cancelAction)
                Button("Save") {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSave(highlightID, trimmed.isEmpty ? nil : trimmed)
                    closeWindow()
                }
                .controlSize(.small)
                .keyboardShortcut(.defaultAction)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && initialNote.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 320, height: 220)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            text = initialNote
        }
    }

    private func closeWindow() {
        if let window = NSApp.keyWindow {
            if let sheet = window.attachedSheet {
                window.endSheet(sheet)
            } else {
                window.close()
            }
        }
        isPresented = false
    }
}

final class NoteEditorWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func show(highlightID: UUID, initialNote: String?, onSave: @escaping (UUID, String?) -> Void) {
        let view = NoteEditorSheet(
            highlightID: highlightID,
            isPresented: .constant(true),
            initialNote: initialNote,
            onSave: onSave
        )
        let host = NSHostingController(rootView: view)
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 220),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.contentViewController = host
        win.title = "Note"
        win.isReleasedWhenClosed = false
        win.delegate = self
        win.center()

        if let mainWindow = NSApp.keyWindow {
            mainWindow.beginSheet(win) { _ in
                win.orderOut(nil)
            }
        } else {
            win.makeKeyAndOrderFront(nil)
        }
        self.window = win
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
