import SwiftUI

struct EditorView: View {
    let url: URL

    @Environment(DocumentStore.self) private var store
    @StateObject private var editor = PDFEditorController()

    @State private var showSignatures = false
    @State private var showTextPrompt = false
    @State private var text = ""
    @State private var savedURL: URL?
    @State private var message: String?

    var body: some View {
        PDFKitView(pdfView: editor.pdfView)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(url.deletingPathExtension().lastPathComponent)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if editor.pdfView.document == nil { editor.load(url) }
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button { showSignatures = true } label: {
                        Label("Signature", systemImage: "signature")
                    }
                    Button { text = ""; showTextPrompt = true } label: {
                        Label("Text", systemImage: "textformat")
                    }
                    Button { editor.addText(Date.now.formatted(date: .numeric, time: .omitted)) } label: {
                        Label("Date", systemImage: "calendar")
                    }
                    Button { editor.addText("✓", fontSize: 18) } label: {
                        Label("Checkmark", systemImage: "checkmark")
                    }
                    Spacer()
                    Button(role: .destructive) { editor.deleteSelected() } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .disabled(editor.selected == nil)
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    if let savedURL, !editor.hasChanges {
                        ShareLink(item: savedURL)
                    }
                    Button("Save", action: save)
                        .disabled(!editor.hasChanges)
                }
            }
            .sheet(isPresented: $showSignatures) {
                SignaturePicker { editor.addImage($0) }
            }
            .alert("Add text", isPresented: $showTextPrompt) {
                TextField("Text", text: $text)
                Button("Cancel", role: .cancel) {}
                Button("Add") {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { editor.addText(trimmed) }
                }
            }
            .alert(message ?? "", isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )) {
                Button("OK") {}
            }
    }

    /// Saves a flattened copy next to the original; the original stays untouched.
    private func save() {
        guard let data = editor.flattenedPDF() else {
            message = "Could not create the signed PDF."
            return
        }
        do {
            let base = url.deletingPathExtension().lastPathComponent
            let saved = try store.save(data, base: base.hasSuffix("(signed)") ? base : "\(base) (signed)")
            savedURL = saved
            editor.markSaved()
            message = "Saved as “\(saved.deletingPathExtension().lastPathComponent)”."
        } catch {
            message = error.localizedDescription
        }
    }
}
