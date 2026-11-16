import SwiftUI

@main
struct CSSignApp: App {
    @State private var documents = DocumentStore()
    @State private var signatures = SignatureStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            TabView {
                LibraryView()
                    .tabItem { Label("Documents", systemImage: "doc.text") }
                SignaturesView()
                    .tabItem { Label("Signatures", systemImage: "signature") }
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
