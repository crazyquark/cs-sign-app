import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

// UIKit pickers wrapped for SwiftUI. Shown inside a `.sheet`, they avoid
// SwiftUI's `.fileImporter` / `.photosPicker`, which silently fail to appear
// when the same view (or another tab) also presents something else.

/// The Files picker. `onPick` gets the chosen URLs, or an empty array on cancel.
struct DocumentPicker: UIViewControllerRepresentable {
    let types: [UTType]
    /// Copy the files into the app's temporary folder (no security scope needed).
    /// Must be false for folders.
    var asCopy = false
    var allowsMultiple = false
    var onPick: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: asCopy)
        picker.allowsMultipleSelection = allowsMultiple
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([URL]) -> Void
        init(onPick: @escaping ([URL]) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onPick([])
        }
    }
}

/// The Photos picker for a single image. Runs out of process, so it needs no
/// photo library permission. iCloud-only photos are downloaded when picked.
struct PhotoPicker: UIViewControllerRepresentable {
    enum Result {
        case picked(UIImage)
        case failed
        case cancelled
    }

    var onFinish: (Result) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onFinish: (Result) -> Void
        init(onFinish: @escaping (Result) -> Void) { self.onFinish = onFinish }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider else {
                onFinish(.cancelled)
                return
            }
            guard provider.canLoadObject(ofClass: UIImage.self) else {
                onFinish(.failed)
                return
            }
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                let image = object as? UIImage
                DispatchQueue.main.async {
                    self.onFinish(image.map(Result.picked) ?? .failed)
                }
            }
        }
    }
}
