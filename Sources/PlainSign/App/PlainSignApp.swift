import SwiftUI

@main
struct PlainSignApp: App {
    @State private var documents: DocumentStore
    @State private var signatures: SignatureStore
    @State private var tab = ScreenshotMode.screen == .signatures ? 1 : 0
    @Environment(\.scenePhase) private var scenePhase

    init() {
        ScreenshotMode.seedIfNeeded() // no-op outside App Store screenshot runs
        _documents = State(initialValue: DocumentStore())
        _signatures = State(initialValue: SignatureStore())
    }

    var body: some Scene {
        WindowGroup {
            TabView(selection: $tab) {
                LibraryView()
                    .tabItem { Label("Documents", systemImage: "doc.text") }
                    .tag(0)
                SignaturesView()
                    .tabItem { Label("Signatures", systemImage: "signature") }
                    .tag(1)
            }
            .environment(documents)
            .environment(signatures)
            .onChange(of: scenePhase) { _, phase in
                // Pick up documents added via Files and signatures synced from other devices.
                guard phase == .active else { return }
                documents.refresh()
                signatures.reload()
            }
        }
    }
}
