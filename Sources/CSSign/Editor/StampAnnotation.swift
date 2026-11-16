import PDFKit
import UIKit

/// A signature image or a piece of text placed on a page. It draws itself, so
/// flattening (redrawing every page into a new PDF) burns it into the content.
final class StampAnnotation: PDFAnnotation {
    enum Content {
        case image(UIImage)
        case text(String)
    }

    let content: Content
    var showsSelection = false

    /// Text is drawn with a font sized to the box height, so pinch-resizing scales it.
    static let lineHeightRatio: CGFloat = 1.25

    init(content: Content, bounds: CGRect) {
        self.content = content
        super.init(bounds: bounds, forType: .stamp, withProperties: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func draw(with box: PDFDisplayBox, in context: CGContext) {
        context.saveGState()
        switch content {
        case .image(let image):
            // PDF space is y-up, which is what CGContext.draw expects for CGImages.
            if let cgImage = image.cgImage {
                context.draw(cgImage, in: bounds)
            }
        case .text(let text):
            UIGraphicsPushContext(context)
            context.translateBy(x: bounds.minX, y: bounds.maxY)
            context.scaleBy(x: 1, y: -1)
            let font = UIFont.systemFont(ofSize: bounds.height / Self.lineHeightRatio)
            (text as NSString).draw(at: .zero, withAttributes: [.font: font, .foregroundColor: UIColor.black])
            UIGraphicsPopContext()
        }
        context.restoreGState()

        if showsSelection {
            context.saveGState()
            context.setStrokeColor(UIColor.systemBlue.cgColor)
            context.setLineWidth(1)
            context.setLineDash(phase: 0, lengths: [4, 3])
            context.stroke(bounds.insetBy(dx: -3, dy: -3))
            context.restoreGState()
        }
    }
}
