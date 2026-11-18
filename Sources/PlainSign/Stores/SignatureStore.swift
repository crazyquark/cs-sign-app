import Foundation
import Observation
import UIKit

/// Saved signatures as transparent PNGs.
///
/// By default they live in Application Support (this device only). The user can
/// link a folder picked through the Files app (e.g. iCloud Drive/Quill Sign); the
/// signatures are then read from and written to that folder, so every device
/// that links the same folder shares them. This needs no iCloud entitlement,
/// which sideloaded apps signed with a free Apple ID can't have.
@MainActor
@Observable
final class SignatureStore {
    struct Signature: Identifiable, @unchecked Sendable {
        let id: String
        let url: URL
        let image: UIImage
    }

    private(set) var signatures: [Signature] = []
    /// The linked sync folder, or nil when signatures are stored on this device only.
    private(set) var syncFolder: URL?
    private(set) var isLoading = false
    var lastError: String?

    private let localFolder: URL
    private static let bookmarkKey = "signatureSyncFolderBookmark"

    /// Where signatures are currently read from and written to.
    var folder: URL { syncFolder ?? localFolder }

    init() {
        localFolder = URL.applicationSupportDirectory.appending(path: "Signatures", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: localFolder, withIntermediateDirectories: true)

        if UserDefaults.standard.data(forKey: Self.bookmarkKey) != nil {
            syncFolder = Self.resolveBookmark()
            if syncFolder == nil {
                lastError = "The sync folder is no longer available. Signatures are being read from this device until you choose the folder again."
            }
        }
        reload()
    }

    // MARK: Loading

    /// Re-reads the folder. Called on launch, when the app returns to the
    /// foreground, and after changes, so edits from other devices show up.
    func reload() {
        let folder = self.folder
        isLoading = true
        Task {
            let loaded = await Task.detached(priority: .userInitiated) {
                Self.loadSignatures(in: folder)
            }.value
            guard folder == self.folder else { return } // folder changed meanwhile
            signatures = loaded
            isLoading = false
        }
    }

    // MARK: Editing

    func add(_ image: UIImage) {
        guard let data = image.pngData() else { return }
        let url = folder.appending(path: Self.newFileName())
        // Show it right away; the write and re-read happen in the background.
        signatures.append(Signature(id: url.lastPathComponent, url: url, image: image))
        Task {
            let ok = await Task.detached { Self.coordinatedWrite(data, to: url) }.value
            if !ok { lastError = "Could not save the signature." }
            reload()
        }
    }

    func delete(_ signature: Signature) {
        signatures.removeAll { $0.id == signature.id }
        Task {
            await Task.detached { Self.coordinatedDelete(signature.url) }.value
            reload()
        }
    }

    // MARK: Sync folder

    /// Links a folder picked with the Files app. Existing signatures are copied
    /// into it, so nothing is lost and devices merge their signatures.
    func linkFolder(_ picked: URL) {
        guard picked.startAccessingSecurityScopedResource() else {
            lastError = "Quill Sign wasn't given access to that folder."
            return
        }
        do {
            UserDefaults.standard.set(try picked.bookmarkData(), forKey: Self.bookmarkKey)
        } catch {
            picked.stopAccessingSecurityScopedResource()
            lastError = "Could not remember that folder: \(error.localizedDescription)"
            return
        }

        let previous = folder
        if let old = syncFolder, old != picked { old.stopAccessingSecurityScopedResource() }
        syncFolder = picked
        isLoading = true
        Task {
            await Task.detached { Self.copyMissing(from: previous, to: picked) }.value
            reload()
        }
    }

    /// Stops syncing. Signatures from the shared folder are copied to this
    /// device first, so they stay available.
    func unlinkFolder() {
        guard let shared = syncFolder else { return }
        let local = localFolder
        syncFolder = nil
        UserDefaults.standard.removeObject(forKey: Self.bookmarkKey)
        isLoading = true
        Task {
            await Task.detached { Self.copyMissing(from: shared, to: local) }.value
            shared.stopAccessingSecurityScopedResource()
            reload()
        }
    }

    private static func resolveBookmark() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale),
              url.startAccessingSecurityScopedResource()
        else { return nil }
        if stale, let fresh = try? url.bookmarkData() {
            UserDefaults.standard.set(fresh, forKey: bookmarkKey)
        }
        return url
    }

    // MARK: File access (off the main thread)
    //
    // Reads and writes go through NSFileCoordinator, which is how the Files
    // providers (iCloud Drive and others) expect to be accessed. A coordinated
    // read also downloads a file that is still only in the cloud.

    /// Timestamped names sort the same way on every device.
    private nonisolated static func newFileName() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "\(formatter.string(from: .now))-\(UUID().uuidString.prefix(8)).png"
    }

    /// PNGs in a folder, including iCloud placeholders for files not downloaded yet.
    private nonisolated static func pngFiles(in folder: URL) -> [URL] {
        let fm = FileManager.default
        let entries = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        var files: [URL] = []
        for url in entries {
            let name = url.lastPathComponent
            if name.hasPrefix("."), name.lowercased().hasSuffix(".png.icloud") {
                // ".NAME.png.icloud" stands for "NAME.png", which is still in the cloud.
                let real = folder.appending(path: String(name.dropFirst().dropLast(".icloud".count)))
                try? fm.startDownloadingUbiquitousItem(at: real)
                files.append(real)
            } else if !name.hasPrefix("."), url.pathExtension.lowercased() == "png" {
                files.append(url)
            }
        }
        return files.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private nonisolated static func loadSignatures(in folder: URL) -> [Signature] {
        pngFiles(in: folder).compactMap { url in
            guard let data = coordinatedRead(url), let image = UIImage(data: data) else { return nil }
            return Signature(id: url.lastPathComponent, url: url, image: image)
        }
    }

    private nonisolated static func copyMissing(from source: URL, to destination: URL) {
        guard source.standardizedFileURL != destination.standardizedFileURL else { return }
        let existing = Set(pngFiles(in: destination).map(\.lastPathComponent))
        for url in pngFiles(in: source) where !existing.contains(url.lastPathComponent) {
            if let data = coordinatedRead(url) {
                coordinatedWrite(data, to: destination.appending(path: url.lastPathComponent))
            }
        }
    }

    private nonisolated static func coordinatedRead(_ url: URL) -> Data? {
        var result: Data?
        var error: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &error) { readURL in
            result = try? Data(contentsOf: readURL)
        }
        return result
    }

    @discardableResult
    private nonisolated static func coordinatedWrite(_ data: Data, to url: URL) -> Bool {
        var ok = false
        var error: NSError?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &error) { writeURL in
            ok = (try? data.write(to: writeURL, options: .atomic)) != nil
        }
        return ok && error == nil
    }

    private nonisolated static func coordinatedDelete(_ url: URL) {
        var error: NSError?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forDeleting, error: &error) { deleteURL in
            try? FileManager.default.removeItem(at: deleteURL)
        }
    }
}
