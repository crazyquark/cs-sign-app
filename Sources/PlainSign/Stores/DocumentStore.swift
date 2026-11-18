import Foundation
import Observation
import UIKit

/// PDFs live directly in the app's Documents folder, so they also show up in
/// Files > On My iPhone > Plain Sign.
@Observable
final class DocumentStore {
    private(set) var documents: [URL] = []
    let folder = URL.documentsDirectory

    init() { refresh() }

    func refresh() {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        documents = urls
            .filter { $0.pathExtension.lowercased() == "pdf" }
            .sorted { Self.modified($0) > Self.modified($1) }
    }

    /// Copies a PDF from the file picker, the share sheet or Files into the library.
    @discardableResult
    func importFile(_ source: URL) throws -> URL {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }

        if source.deletingLastPathComponent().standardizedFileURL == folder.standardizedFileURL {
            return source // already in the library
        }
        let dest = uniqueURL(base: source.deletingPathExtension().lastPathComponent)
        try FileManager.default.copyItem(at: source, to: dest)
        refresh()
        return dest
    }

    @discardableResult
    func save(_ data: Data, base: String) throws -> URL {
        let dest = uniqueURL(base: base)
        try data.write(to: dest, options: .atomic)
        refresh()
        return dest
    }

    /// Turns camera scans into a Letter-width PDF with reasonably sized JPEG pages.
    @discardableResult
    func saveScan(_ images: [UIImage]) throws -> URL {
        let pageWidth: CGFloat = 612
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let data = renderer.pdfData { context in
            for image in images {
                let height = pageWidth * image.size.height / max(image.size.width, 1)
                let rect = CGRect(x: 0, y: 0, width: pageWidth, height: height)
                context.beginPage(withBounds: rect, pageInfo: [:])
                Self.compressed(image, maxWidth: 1700).draw(in: rect)
            }
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm"
        return try save(data, base: "Scan \(formatter.string(from: .now))")
    }

    func delete(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        refresh()
    }

    private func uniqueURL(base: String) -> URL {
        var candidate = folder.appending(path: "\(base).pdf")
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appending(path: "\(base) \(n).pdf")
            n += 1
        }
        return candidate
    }

    static func modified(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    private static func compressed(_ image: UIImage, maxWidth: CGFloat) -> UIImage {
        let scale = min(1, maxWidth / max(image.size.width, 1))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        // JPEG-backed images are embedded as JPEG in the PDF, which keeps scans small.
        return resized.jpegData(compressionQuality: 0.7).flatMap(UIImage.init(data:)) ?? resized
    }
}
