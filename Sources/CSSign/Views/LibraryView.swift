import PDFKit
import SwiftUI
import VisionKit

struct LibraryView: View {
    @Environment(DocumentStore.self) private var store
    @State private var path: [URL] = []
    @State private var showImporter = false
    @State private var showScanner = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if store.documents.isEmpty {
                    ContentUnavailableView(
                        "No documents",
                        systemImage: "doc.badge.plus",
                        description: Text("Import a PDF, scan a paper document, or share a PDF to CS Sign from another app.")
                    )
                } else {
                    List {
                        ForEach(store.documents, id: \.self) { url in
                            NavigationLink(value: url) { DocumentRow(url: url) }
                                .contextMenu {
                                    ShareLink(item: url)
                                    Button(role: .destructive) { store.delete(url) } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                        .onDelete { offsets in
                            offsets.map { store.documents[$0] }.forEach(store.delete)
                        }
                    }
                }
            }
            .navigationTitle("Documents")
            .navigationDestination(for: URL.self) { EditorView(url: $0) }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button { showImporter = true } label: {
                            Label("Import PDF", systemImage: "folder")
                        }
                        if VNDocumentCameraViewController.isSupported {
                            Button { showScanner = true } label: {
                                Label("Scan Document", systemImage: "doc.viewfinder")
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.pdf], allowsMultipleSelection: true) { result in
                do {
                    for url in try result.get() { try store.importFile(url) }
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            .fullScreenCover(isPresented: $showScanner) {
                DocumentScanner { images in
                    showScanner = false
                    guard !images.isEmpty else { return }
                    do { path = [try store.saveScan(images)] } catch { errorMessage = error.localizedDescription }
                }
                .ignoresSafeArea()
            }
            .onOpenURL { url in
                do { path = [try store.importFile(url)] } catch { errorMessage = error.localizedDescription }
            }
            .refreshable { store.refresh() }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
}

private struct DocumentRow: View {
    let url: URL
    @State private var thumbnail: UIImage?

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let thumbnail {
                    Image(uiImage: thumbnail).resizable().scaledToFit()
                } else {
                    Color.secondary.opacity(0.15)
                }
            }
            .frame(width: 44, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 2) {
                Text(url.deletingPathExtension().lastPathComponent).lineLimit(2)
                Text(DocumentStore.modified(url), format: .dateTime.day().month().year().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: url) {
            thumbnail = PDFDocument(url: url)?.page(at: 0)?.thumbnail(of: CGSize(width: 88, height: 112), for: .cropBox)
        }
    }
}
