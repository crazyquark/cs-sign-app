import SwiftUI

/// The Signatures tab: manage saved signatures and the sync folder.
struct SignaturesView: View {
    @Environment(SignatureStore.self) private var store
    @State private var addSheet: AddSignatureSheet?
    @State private var showSync = false

    var body: some View {
        NavigationStack {
            Group {
                if store.signatures.isEmpty && store.isLoading {
                    ProgressView()
                } else if store.signatures.isEmpty {
                    ContentUnavailableView {
                        Label("No signatures", systemImage: "signature")
                    } description: {
                        Text("Draw your signature, or import a photo or scan of it, and reuse it on any document.")
                    } actions: {
                        Menu {
                            AddSignatureMenuItems(sheet: $addSheet)
                        } label: {
                            Text("Add Signature")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    ScrollView { SignatureGrid() }
                        .refreshable { store.reload() }
                }
            }
            .addSignatureFlows(sheet: $addSheet)
            .navigationTitle("Signatures")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSync = true } label: {
                        Label("Sync", systemImage: store.syncFolder == nil ? "icloud.slash" : "icloud")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        AddSignatureMenuItems(sheet: $addSheet)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showSync) {
            SyncSettingsView()
        }
        .alert("Sync", isPresented: Binding(
            get: { store.lastError != nil },
            set: { if !$0 { store.lastError = nil } }
        )) {
            Button("OK") {}
        } message: {
            Text(store.lastError ?? "")
        }
    }
}

/// Choose or stop using the folder that signatures sync through.
struct SyncSettingsView: View {
    @Environment(SignatureStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showPicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let folder = store.syncFolder {
                        LabeledContent("Sync folder") {
                            Label(folder.lastPathComponent, systemImage: "folder")
                        }
                        LabeledContent("Signatures", value: "\(store.signatures.count)")
                        Button("Choose Another Folder") { showPicker = true }
                        Button("Stop Syncing", role: .destructive) { store.unlinkFolder() }
                    } else {
                        Label("Signatures are stored on this device only.", systemImage: "iphone")
                            .foregroundStyle(.secondary)
                        Button("Choose Sync Folder…") { showPicker = true }
                    }
                } footer: {
                    Text("""
                    Pick a folder in iCloud Drive, for example “Plain Sign”, and pick the same \
                    folder on your other devices. Signatures are saved there as PNG files, so \
                    every device using that folder sees them. Your current signatures are \
                    copied in when you choose a folder, and a copy stays on this device if you \
                    stop syncing.
                    """)
                }
            }
            .navigationTitle("Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $showPicker) {
                DocumentPicker(types: [.folder]) { urls in
                    showPicker = false
                    if let url = urls.first { store.linkFolder(url) }
                }
                .ignoresSafeArea()
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Sheet shown from the editor to pick a signature to place.
struct SignaturePicker: View {
    var onPick: (UIImage) -> Void

    @Environment(SignatureStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var addSheet: AddSignatureSheet?

    var body: some View {
        NavigationStack {
            ScrollView {
                if store.signatures.isEmpty {
                    Text("No saved signatures yet.")
                        .foregroundStyle(.secondary)
                        .padding(.top, 40)
                }
                SignatureGrid { signature in
                    onPick(signature.image)
                    dismiss()
                }
            }
            .navigationTitle("Choose Signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        AddSignatureMenuItems(sheet: $addSheet)
                    } label: {
                        Label("New", systemImage: "plus")
                    }
                }
            }
            .addSignatureFlows(sheet: $addSheet)
        }
        .presentationDetents([.medium, .large])
    }
}

struct SignatureGrid: View {
    var onTap: ((SignatureStore.Signature) -> Void)?
    @Environment(SignatureStore.self) private var store

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            ForEach(store.signatures) { signature in
                Image(uiImage: signature.image)
                    .resizable()
                    .scaledToFit()
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
                    // Signatures are dark ink; keep a white card in dark mode too.
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary))
                    .contentShape(Rectangle())
                    .onTapGesture { onTap?(signature) }
                    .contextMenu {
                        Button(role: .destructive) { store.delete(signature) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .padding()
    }
}
