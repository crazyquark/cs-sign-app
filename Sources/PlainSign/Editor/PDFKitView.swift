import PDFKit
import SwiftUI

struct PDFKitView: UIViewRepresentable {
    let pdfView: PDFView

    func makeUIView(context: Context) -> PDFView { pdfView }
    func updateUIView(_ view: PDFView, context: Context) {}
}
