import SwiftUI
import UniformTypeIdentifiers

// MARK: - Image processing

/// Turns an imported image (a photo or scan of a signature on paper, or an
/// already transparent PNG) into a clean signature with a transparent background.
enum SignatureImageProcessor {
    struct Result {
        let image: UIImage
        /// The source already had a transparent background.
        let wasTransparent: Bool
    }

    static func prepare(_ source: UIImage, removeBackground: Bool) -> Result? {
        // Render upright (applies EXIF orientation), downscaled, into an RGBA buffer.
        let maxSide: CGFloat = 1600
        let scale = min(1, maxSide / max(source.size.width, source.size.height, 1))
        let width = Int((source.size.width * scale).rounded())
        let height = Int((source.size.height * scale).rounded())
        guard width > 0, height > 0,
              let context = CGContext(
                  data: nil, width: width, height: height,
                  bitsPerComponent: 8, bytesPerRow: width * 4,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ),
              let raw = context.data
        else { return nil }

        UIGraphicsPushContext(context)
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        source.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        UIGraphicsPopContext()

        let count = width * height
        let pixels = raw.bindMemory(to: UInt8.self, capacity: count * 4)

        // Already cut out? Then leave the pixels alone and just crop.
        var transparent = 0
        for i in 0..<count where pixels[i * 4 + 3] < 250 { transparent += 1 }
        let wasTransparent = transparent > count / 100

        if removeBackground && !wasTransparent {
            removePaper(pixels: pixels, count: count)
        }

        guard let full = context.makeImage(),
              let crop = inkBounds(pixels: pixels, width: width, height: height),
              let cropped = full.cropping(to: crop)
        else { return nil }
        return Result(image: UIImage(cgImage: cropped), wasTransparent: wasTransparent)
    }

    /// Makes the paper transparent: pixels near the paper's brightness fade out,
    /// darker (ink) pixels stay, keeping their color.
    private static func removePaper(pixels: UnsafeMutablePointer<UInt8>, count: Int) {
        func luminance(_ i: Int) -> Int {
            (Int(pixels[i * 4]) * 299 + Int(pixels[i * 4 + 1]) * 587 + Int(pixels[i * 4 + 2]) * 114) / 1000
        }

        // Paper brightness = the 90th percentile, which copes with shadows and off-white paper.
        var histogram = [Int](repeating: 0, count: 256)
        for i in 0..<count { histogram[luminance(i)] += 1 }
        var seen = 0
        var paper = 255
        for level in 0..<256 {
            seen += histogram[level]
            if seen >= count * 9 / 10 { paper = level; break }
        }
        guard paper > 60 else { return } // a dark image; nothing sensible to remove

        let high = Double(paper) * 0.88 // at or above: background
        let low = Double(paper) * 0.55  // at or below: full ink
        for i in 0..<count {
            let alpha = min(1, max(0, (high - Double(luminance(i))) / (high - low)))
            // Premultiplied RGBA: scale color by the new alpha.
            for c in 0..<3 { pixels[i * 4 + c] = UInt8(Double(pixels[i * 4 + c]) * alpha) }
            pixels[i * 4 + 3] = UInt8(Double(pixels[i * 4 + 3]) * alpha)
        }
    }

    /// Bounding box of visible pixels, padded slightly. Buffer row 0 is the top.
    private static func inkBounds(pixels: UnsafeMutablePointer<UInt8>, width: Int, height: Int) -> CGRect? {
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width where pixels[(y * width + x) * 4 + 3] > 24 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        let pad = 8
        let x0 = max(0, minX - pad), y0 = max(0, minY - pad)
        let x1 = min(width, maxX + pad + 1), y1 = min(height, maxY + pad + 1)
        return CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
    }
}

// MARK: - Adding signatures (draw or import)

/// What the add-signature flow is showing. A single `.sheet(item:)` presents
/// all of these, since SwiftUI handles only one presentation per view reliably.
enum AddSignatureSheet: Identifiable {
    case draw
    case files
    case photos
    case preview(UIImage)

    var id: String {
        switch self {
        case .draw: "draw"
        case .files: "files"
        case .photos: "photos"
        case .preview: "preview"
        }
    }
}

/// Menu items for adding a signature; pair with `.addSignatureFlows`.
struct AddSignatureMenuItems: View {
    @Binding var sheet: AddSignatureSheet?

    var body: some View {
        Button { sheet = .draw } label: { Label("Draw Signature", systemImage: "pencil.and.scribble") }
        Button { sheet = .photos } label: { Label("Import from Photos", systemImage: "photo") }
        Button { sheet = .files } label: { Label("Import from Files", systemImage: "folder") }
    }
}

extension View {
    /// The drawing pad, the Photos and Files pickers, and the import preview.
    func addSignatureFlows(sheet: Binding<AddSignatureSheet?>) -> some View {
        modifier(AddSignatureFlows(sheet: sheet))
    }
}

private struct AddSignatureFlows: ViewModifier {
    @Binding var sheet: AddSignatureSheet?

    @Environment(SignatureStore.self) private var store
    /// A picked image (or an error), shown once the picker has finished closing.
    @State private var pendingImage: UIImage?
    @State private var pendingError: String?
    @State private var errorMessage: String?

    func body(content: Content) -> some View {
        content
            .sheet(item: $sheet, onDismiss: afterPickerClosed) { which in
                switch which {
                case .draw:
                    SignaturePadView { store.add($0) }
                case .files:
                    DocumentPicker(types: [.image], asCopy: true) { urls in
                        if let url = urls.first {
                            if let image = (try? Data(contentsOf: url)).flatMap(UIImage.init(data:)) {
                                pendingImage = image
                            } else {
                                pendingError = "That file isn't an image Plain Sign can read."
                            }
                        }
                        sheet = nil
                    }
                    .ignoresSafeArea()
                case .photos:
                    PhotoPicker { result in
                        switch result {
                        case .picked(let image): pendingImage = image
                        case .failed: pendingError = "Could not load that photo."
                        case .cancelled: break
                        }
                        sheet = nil
                    }
                    .ignoresSafeArea()
                case .preview(let image):
                    ImportSignatureView(source: image) { store.add($0) }
                }
            }
            .alert("Import", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "")
            }
    }

    /// Runs when any of the sheets has fully closed; chains into the preview.
    private func afterPickerClosed() {
        if let image = pendingImage {
            pendingImage = nil
            sheet = .preview(image)
        } else if let error = pendingError {
            pendingError = nil
            errorMessage = error
        }
    }
}

/// Preview of an imported signature, with background removal on or off.
struct ImportSignatureView: View {
    let source: UIImage
    var onSave: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var removeBackground = true
    @State private var result: SignatureImageProcessor.Result?
    @State private var processing = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ZStack {
                        Checkerboard().opacity(0.5)
                        if let result {
                            Image(uiImage: result.image).resizable().scaledToFit().padding(16)
                        } else if processing {
                            ProgressView()
                        } else {
                            Text("No signature found in this image.").foregroundStyle(.secondary)
                        }
                    }
                    .frame(height: 200)
                    .listRowInsets(EdgeInsets())
                } footer: {
                    Text("The checkered pattern shows transparent areas.")
                }

                Section {
                    Toggle("Remove paper background", isOn: $removeBackground)
                        .disabled(result?.wasTransparent == true)
                } footer: {
                    if result?.wasTransparent == true {
                        Text("This image already has a transparent background.")
                    } else {
                        Text("Works best with dark ink on plain light paper, photographed in even light.")
                    }
                }
            }
            .navigationTitle("Import Signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let result { onSave(result.image) }
                        dismiss()
                    }
                    .disabled(result == nil)
                }
            }
            .task(id: removeBackground) {
                processing = true
                let source = source, remove = removeBackground
                result = await Task.detached(priority: .userInitiated) {
                    SignatureImageProcessor.prepare(source, removeBackground: remove)
                }.value
                processing = false
            }
        }
    }
}

private struct Checkerboard: View {
    var body: some View {
        Canvas { context, size in
            let cell: CGFloat = 10
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            for row in 0..<Int(size.height / cell) + 1 {
                for col in 0..<Int(size.width / cell) + 1 where (row + col).isMultiple(of: 2) {
                    let rect = CGRect(x: CGFloat(col) * cell, y: CGFloat(row) * cell, width: cell, height: cell)
                    context.fill(Path(rect), with: .color(Color(white: 0.85)))
                }
            }
        }
    }
}
